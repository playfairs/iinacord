import AppKit
import Darwin
import Foundation
import XCTest

@testable import IINAcord

final class DiscordWriteToSocket: XCTestCase {
  private var clientId: String { Config.clientID }
  private let activityDetails = "Hello from IINA"
  private let activityState = "Watching IINA"
  private let socketNames = (0..<10).map { "discord-ipc-\($0)" }
  private let candidateDirs = [
    ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"],
    ProcessInfo.processInfo.environment["TMPDIR"],
    ProcessInfo.processInfo.environment["TMP"],
    ProcessInfo.processInfo.environment["TEMP"],
    "/tmp",
  ].compactMap { $0 }

  func testWriteToDiscordSocket() throws {
    guard let iinaApp = findIINAApplication() else {
      throw XCTSkip("IINA is not running; skipping Discord RPC test.")
    }
    print("IINA is running with pid: \(iinaApp.processIdentifier)")

    guard let socketPath = findDiscordSocket() else {
      throw XCTSkip("Discord IPC socket not found")
    }

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    XCTAssertGreaterThanOrEqual(fd, 0, "socket create failed")
    defer { close(fd) }

    var addr = sockaddr_un()
    addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = socketPath.utf8CString
    withUnsafeMutableBytes(of: &addr.sun_path) { dest in
      let count = min(dest.count, pathBytes.count)
      pathBytes.withUnsafeBufferPointer { src in
        dest.baseAddress?.copyMemory(from: src.baseAddress!, byteCount: count)
      }
    }

    let pathLength = min(pathBytes.count, MemoryLayout.size(ofValue: addr.sun_path))
    let sockLen = socklen_t(
      MemoryLayout.size(ofValue: addr.sun_len) + MemoryLayout.size(ofValue: addr.sun_family)
        + pathLength)
    let connectResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
        connect(fd, sockPtr, sockLen)
      }
    }
    XCTAssertGreaterThanOrEqual(
      connectResult, 0, "socket connect failed: \(String(cString: strerror(errno)))")
    print("Discord IPC socket connected")

    let handshake: [String: Any] = ["v": 1, "client_id": clientId]
    let handshakePayload = try XCTUnwrap(jsonData(from: handshake), "failed to serialize handshake")
    print("Sending HANDSHAKE")
    XCTAssertTrue(
      sendPacket(fd: fd, opcode: 0, payload: handshakePayload), "failed to send handshake")

    let handshakeResponse = try XCTUnwrap(readPacket(fd: fd), "failed to read handshake response")
    XCTAssertEqual(handshakeResponse.opcode, 1, "unexpected opcode for handshake response")
    print(
      "Received packet op=\(handshakeResponse.opcode) payload=\(String(data: handshakeResponse.payload, encoding: .utf8) ?? "<invalid utf8>")"
    )

    let handshakeJson = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: handshakeResponse.payload, options: [])
        as? [String: Any], "invalid handshake JSON")
    let evt = handshakeJson["evt"] as? String
    XCTAssertEqual(evt, "READY", "expected READY event, got \(evt ?? "nil")")
    print("Received READY")

    let nonce = UUID().uuidString
    let activityPayload: [String: Any] = [
      "cmd": "SET_ACTIVITY",
      "args": [
        "pid": ProcessInfo.processInfo.processIdentifier,
        "activity": [
          "type": 3,
          "details": activityDetails,
          "state": activityState,
        ],
      ],
      "nonce": nonce,
    ]

    let activityData = try XCTUnwrap(
      jsonData(from: activityPayload), "failed to serialize activity payload")
    print("Sending SET_ACTIVITY")
    XCTAssertTrue(
      sendPacket(fd: fd, opcode: 1, payload: activityData), "failed to send SET_ACTIVITY")

    let activityResponse = try XCTUnwrap(readPacket(fd: fd), "failed to read SET_ACTIVITY response")
    let activityResponseString =
      String(data: activityResponse.payload, encoding: .utf8) ?? "<invalid utf8>"
    print("Received packet op=\(activityResponse.opcode) payload=\(activityResponseString)")

    let responseJson = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: activityResponse.payload, options: [])
        as? [String: Any], "invalid response JSON")
    let responseNonce = responseJson["nonce"] as? String
    XCTAssertEqual(responseNonce, nonce, "nonce mismatch")
    print("SET_ACTIVITY response nonce matches")
  }

  private func findDiscordSocket() -> String? {
    for directory in candidateDirs {
      for socketName in socketNames {
        let path = "\(directory)/\(socketName)"
        if FileManager.default.fileExists(atPath: path) {
          print("Discord socket discovered at \(path)")
          return path
        }
      }
    }
    return nil
  }

  private func writeFully(fd: Int32, data: Data) -> Bool {
    var bytesSent = 0
    let total = data.count
    return data.withUnsafeBytes { raw in
      guard let base = raw.baseAddress else { return false }
      while bytesSent < total {
        let sent = write(fd, base.advanced(by: bytesSent), total - bytesSent)
        if sent <= 0 {
          return false
        }
        bytesSent += sent
      }
      return true
    }
  }

  private func sendPacket(fd: Int32, opcode: UInt32, payload: Data) -> Bool {
    var header = Data()
    var opLE = opcode.littleEndian
    var sizeLE = UInt32(payload.count).littleEndian
    header.append(Data(bytes: &opLE, count: MemoryLayout.size(ofValue: opLE)))
    header.append(Data(bytes: &sizeLE, count: MemoryLayout.size(ofValue: sizeLE)))
    header.append(payload)
    return writeFully(fd: fd, data: header)
  }

  private func readExactly(fd: Int32, count: Int) -> Data? {
    var remaining = count
    var buffer = Data()
    while remaining > 0 {
      var chunk = [UInt8](repeating: 0, count: remaining)
      let bytesRead = read(fd, &chunk, remaining)
      if bytesRead <= 0 {
        return nil
      }
      buffer.append(chunk, count: bytesRead)
      remaining -= bytesRead
    }
    return buffer
  }

  private func readPacket(fd: Int32) -> (opcode: UInt32, payload: Data)? {
    guard let header = readExactly(fd: fd, count: 8) else {
      return nil
    }
    let op = header.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }.littleEndian
    let size = header.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }.littleEndian
    guard size <= 16_000_000, let payload = readExactly(fd: fd, count: Int(size)) else {
      return nil
    }
    return (op, payload)
  }

  private func jsonData(from dictionary: [String: Any]) -> Data? {
    return try? JSONSerialization.data(withJSONObject: dictionary)
  }

  private func findIINAApplication() -> NSRunningApplication? {
    return NSWorkspace.shared.runningApplications.first { app in
      guard let bundleID = app.bundleIdentifier else { return false }
      return bundleID == "tv.kaleidoscope.iina" || app.localizedName == "IINA"
    }
  }
}
