import AppKit
import Foundation

final class DiscordRPC {
  private enum ConnectionState {
    case disconnected
    case connecting
    case handshaking
    case ready
    case closing
  }

  private struct DiscordPacket {
    let op: UInt32
    let payloadLength: UInt32
    let payloadString: String
    let payloadData: Data
  }

  private var timer: Timer?
  private var socketFd: Int32 = -1
  private(set) var connected = false
  private var state: ConnectionState = .disconnected
  private var currentActivity: DiscordActivity?
  var onLog: ((String) -> Void)?
  private var clientId: String { Config.clientID }

  func startMonitoring(_ handler: @escaping (Bool) -> Void) {
    onLog?("starting Discord availability monitor")
    checkOnce(handler: handler)
    timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      self?.checkOnce(handler: handler)
    }
  }

  private func checkOnce(handler: (Bool) -> Void) {
    let running = NSWorkspace.shared.runningApplications.contains { app in
      (app.bundleIdentifier ?? "").lowercased().contains("discord")
        || (app.localizedName ?? "").lowercased().contains("discord")
    }
    onLog?(running ? "Discord is running" : "Discord is not running")
    if running {
      if connectToDiscord() {
        onLog?("Discord RPC connection ready")
        connected = true
      } else {
        onLog?("Discord IPC connection failed")
        connected = false
      }
    } else {
      disconnect()
      onLog?("Discord disconnected")
    }
    handler(connected)
  }

  func update(with state: PlaybackState) {
    currentActivity = DiscordActivity(from: state)
    onLog?(
      "update called connected=\(connected) title=\(state.title) paused=\(state.paused) idle=\(state.idle)"
    )
    onLog?("prepared activity for \(state.title)")
    if connected {
      _ = sendActivity(currentActivity!)
    } else {
      onLog?("unable to send activity: not connected")
    }
  }

  func showPlaceholderActivityIfNeeded() {
    guard connected else { return }
    currentActivity = DiscordActivity(details: "Watching IINA", state: "Idle", start: nil, end: nil)
    _ = sendActivity(currentActivity!)
  }

  func clear() {
    if connected {
      _ = sendClear()
    }
    currentActivity = nil
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    disconnect()
  }

  private func disconnect() {
    if socketFd >= 0 {
      close(socketFd)
      socketFd = -1
    }
    connected = false
    state = .disconnected
    onLog?("Discord IPC disconnected")
  }

  private func findDiscordSocket() -> String? {
    let candidateDirs: [String] = [
      ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"],
      ProcessInfo.processInfo.environment["TMPDIR"],
      ProcessInfo.processInfo.environment["TMP"],
      ProcessInfo.processInfo.environment["TEMP"],
      "/tmp",
    ].compactMap { $0 }
    for directory in candidateDirs {
      for index in 0..<10 {
        let path = "\(directory)/discord-ipc-\(index)"
        if FileManager.default.fileExists(atPath: path) {
          onLog?("Discord socket discovered at \(path)")
          return path
        }
      }
    }
    let pathset = ["/tmp", "/var/folders"].compactMap { root -> String? in
      return findSocketUnder(root)
    }.compactMap { $0 }.first
    if let pathset = pathset {
      onLog?("found Discord IPC socket under \(pathset)")
      return pathset
    }
    return nil
  }

  private func findSocketUnder(_ root: String) -> String? {
    let manager = FileManager.default
    guard let enumerator = manager.enumerator(atPath: root) else {
      return nil
    }
    while let item = enumerator.nextObject() as? String {
      if item.hasPrefix("discord-ipc-") {
        let path = root + "/" + item
        if manager.fileExists(atPath: path) {
          return path
        }
      }
    }
    return nil
  }

  private func connectToDiscord() -> Bool {
    if connected {
      return true
    }
    if socketFd >= 0 {
      close(socketFd)
      socketFd = -1
    }
    guard let path = findDiscordSocket() else {
      onLog?("Discord IPC socket not found")
      return false
    }
    onLog?("attempting Discord IPC socket at \(path)")
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      onLog?("socket create failed: \(String(cString: strerror(errno)))")
      return false
    }
    var addr = sockaddr_un()
    addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = path.utf8CString
    path.utf8CString.withUnsafeBufferPointer { bytes in
      withUnsafeMutableBytes(of: &addr.sun_path) { dest in
        let count = min(dest.count, bytes.count)
        dest.baseAddress?.copyMemory(from: bytes.baseAddress!, byteCount: count)
      }
    }
    let pathLength = min(pathBytes.count, MemoryLayout.size(ofValue: addr.sun_path))
    let len = socklen_t(
      MemoryLayout.size(ofValue: addr.sun_len) + MemoryLayout.size(ofValue: addr.sun_family)
        + pathLength)
    let connectResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        connect(fd, sockaddrPtr, len)
      }
    }
    guard connectResult >= 0 else {
      onLog?("socket connect failed: \(String(cString: strerror(errno)))")
      close(fd)
      return false
    }
    socketFd = fd
    onLog?("Discord IPC socket connected")
    state = .handshaking
    guard performHandshake() else {
      disconnect()
      return false
    }
    state = .ready
    connected = true
    return true
  }

  private func performHandshake() -> Bool {
    let handshake: [String: Any] = ["v": 1, "client_id": clientId]
    guard let payload = try? JSONSerialization.data(withJSONObject: handshake) else {
      onLog?("handshake serialization failed")
      return false
    }
    guard sendPacket(op: 0, payload: payload) else {
      onLog?("handshake send failed")
      return false
    }
    guard let packet = readPacket() else {
      onLog?("handshake response failed")
      return false
    }
    guard packet.op == 1 else {
      onLog?("handshake failed: unexpected opcode \(packet.op)")
      return false
    }
    guard
      let json = try? JSONSerialization.jsonObject(with: packet.payloadData, options: [])
        as? [String: Any]
    else {
      onLog?("handshake failed: invalid JSON response")
      return false
    }
    if let code = json["code"] as? Int {
      onLog?("handshake failed: RPC error code=\(code) message=\(json["message"] ?? "unknown")")
      return false
    }
    guard let evt = json["evt"] as? String, evt == "READY" else {
      onLog?("handshake failed: expected READY event, got \(json["evt"] ?? "none")")
      return false
    }
    onLog?("Received READY")
    return true
  }

  @discardableResult
  private func sendActivity(_ activity: DiscordActivity) -> Bool {
    let nonce = UUID().uuidString
    onLog?("Sending SET_ACTIVITY")
    var activityFields: [String: Any] = [
      "type": 3,
      "details": activity.details,
      "state": activity.state,
      "assets": [
        "large_image": DiscordAssets.largeImage,
        "large_text": "IINAcord",
      ],
    ]
    if let timestamps = timestampsData(for: activity) {
      activityFields["timestamps"] = timestamps
    }
    let activityPayload: [String: Any] = [
      "cmd": "SET_ACTIVITY",
      "args": [
        "pid": ProcessInfo.processInfo.processIdentifier,
        "activity": activityFields,
      ],
      "nonce": nonce,
    ]
    guard let payload = try? JSONSerialization.data(withJSONObject: activityPayload) else {
      onLog?("activity serialization failed")
      return false
    }
    guard sendPacket(op: 1, payload: payload) else {
      onLog?("activity send failed")
      disconnect()
      return false
    }
    onLog?("sent SET_ACTIVITY packet")
    guard let response = readPacket() else {
      onLog?("SET_ACTIVITY response failed")
      return false
    }
    return handleCommandResponse(response, expectedNonce: nonce, command: "SET_ACTIVITY")
  }

  @discardableResult
  private func sendClear() -> Bool {
    let nonce = UUID().uuidString
    onLog?("Sending SET_ACTIVITY clear")
    let clearPayload: [String: Any] = [
      "cmd": "SET_ACTIVITY",
      "args": [
        "pid": ProcessInfo.processInfo.processIdentifier,
        "activity": NSNull(),
      ],
      "nonce": nonce,
    ]
    guard let payload = try? JSONSerialization.data(withJSONObject: clearPayload) else {
      onLog?("clear serialization failed")
      return false
    }
    guard sendPacket(op: 1, payload: payload) else {
      onLog?("clear send failed")
      return false
    }
    onLog?("sent SET_ACTIVITY clear packet")
    guard let response = readPacket() else {
      onLog?("SET_ACTIVITY clear response failed")
      return false
    }
    return handleCommandResponse(response, expectedNonce: nonce, command: "SET_ACTIVITY")
  }

  private func handleCommandResponse(
    _ packet: DiscordPacket, expectedNonce: String, command: String
  ) -> Bool {
    guard packet.op == 1 else {
      onLog?("unexpected response opcode \(packet.op)")
      return false
    }
    guard
      let json = try? JSONSerialization.jsonObject(with: packet.payloadData, options: [])
        as? [String: Any]
    else {
      onLog?("invalid JSON response for \(command)")
      return false
    }
    if let evt = json["evt"] as? String, evt == "ERROR" {
      onLog?("RPC error event for \(command): \(json)")
      if let data = json["data"] as? [String: Any] {
        onLog?("RPC error code=\(data["code"] ?? "unknown")")
        onLog?("RPC error message=\(data["message"] ?? "unknown")")
      }
      onLog?("RPC nonce=\(expectedNonce)")
      return false
    }
    if let data = json["data"] as? [String: Any], let code = data["code"] as? Int {
      onLog?("RPC error code=\(code)")
      onLog?("RPC error message=\(data["message"] ?? "unknown")")
      onLog?("RPC command=\(command)")
      onLog?("RPC nonce=\(expectedNonce)")
      return false
    }
    let responseNonce = json["nonce"] as? String
    guard responseNonce == expectedNonce else {
      onLog?("response nonce mismatch expected=\(expectedNonce) got=\(responseNonce ?? "nil")")
      return false
    }
    let cmd = json["cmd"] as? String
    if cmd == command {
      onLog?("Received \(command) response")
      onLog?(command == "SET_ACTIVITY" ? "Discord activity updated" : "Discord activity cleared")
      return true
    }
    onLog?("unexpected response for \(command): \(json)")
    return false
  }

  private func timestampsData(for activity: DiscordActivity) -> [String: Int]? {
    guard let start = activity.start, let end = activity.end else {
      return nil
    }
    return ["start": Int(start.timeIntervalSince1970), "end": Int(end.timeIntervalSince1970)]
  }

  private func sendPacket(op: Int32, payload: Data) -> Bool {
    let size = Int32(payload.count)
    var packet = Data()
    var opCode = op.littleEndian
    var payloadSize = size.littleEndian
    packet.append(Data(bytes: &opCode, count: MemoryLayout.size(ofValue: opCode)))
    packet.append(Data(bytes: &payloadSize, count: MemoryLayout.size(ofValue: payloadSize)))
    packet.append(payload)
    onLog?("sending packet op=\(op) payloadLength=\(payload.count)")
    return writeFully(data: packet)
  }

  private func writeFully(data: Data) -> Bool {
    var bytesWritten = 0
    let length = data.count
    return data.withUnsafeBytes { rawBufferPointer in
      guard let baseAddress = rawBufferPointer.baseAddress else { return false }
      while bytesWritten < length {
        let written = write(socketFd, baseAddress.advanced(by: bytesWritten), length - bytesWritten)
        if written <= 0 {
          onLog?("write error: \(String(cString: strerror(errno)))")
          return false
        }
        bytesWritten += written
      }
      return true
    }
  }

  private func readPacket() -> DiscordPacket? {
    guard let header = readExactly(count: 8) else {
      onLog?("readPacket failed: unable to read header")
      return nil
    }
    let op = header.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }.littleEndian
    let size = header.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }.littleEndian
    onLog?("readPacket header op=\(op) size=\(size)")
    guard size <= 16_000_000 else {
      onLog?("readPacket failed: invalid payload size \(size)")
      return nil
    }
    guard let payloadData = readExactly(count: Int(size)) else {
      onLog?("readPacket failed: unable to read payload of size \(size)")
      return nil
    }
    let payloadString = String(data: payloadData, encoding: .utf8) ?? ""
    onLog?("received packet op=\(op) payload=\(payloadString)")
    return DiscordPacket(
      op: op, payloadLength: size, payloadString: payloadString, payloadData: payloadData)
  }

  private func readExactly(count: Int) -> Data? {
    var remaining = count
    var data = Data()
    while remaining > 0 {
      var buffer = [UInt8](repeating: 0, count: remaining)
      let readBytes = read(socketFd, &buffer, remaining)
      if readBytes <= 0 {
        onLog?("read error: \(String(cString: strerror(errno)))")
        return nil
      }
      data.append(buffer, count: readBytes)
      remaining -= readBytes
    }
    return data
  }
}
