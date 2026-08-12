import Foundation

final class IPCConnection {
  private let fd: Int32
  var onMessage: ((IPCMessage) -> Void)?
  var onLog: ((String) -> Void)?

  init(fd: Int32) {
    self.fd = fd
  }

  func start() {
    DispatchQueue.global(qos: .background).async { [weak self] in
      guard let self = self else { return }
      self.onLog?("reading data from client")
      var buffer = [UInt8](repeating: 0, count: 8192)
      var data = Data()
      while true {
        let readBytes = read(self.fd, &buffer, buffer.count)
        if readBytes > 0 {
          data.append(buffer, count: readBytes)
        } else if readBytes == 0 {
          break
        } else {
          self.onLog?("read error: \(String(cString: strerror(errno)))")
          break
        }
      }
      if !data.isEmpty {
        let rawPayload = String(data: data, encoding: .utf8) ?? "<binary>"
        self.onLog?("raw IPC payload: \(rawPayload)")
        let decoder = JSONDecoder()
        do {
          let msg = try decoder.decode(IPCMessage.self, from: data)
          self.onLog?("decoded IPC message: \(msg)")
          self.onMessage?(msg)
        } catch {
          self.onLog?("failed to decode IPC message: \(error)")
          self.onLog?("raw IPC payload: \(rawPayload)")
        }
      } else {
        self.onLog?("no data received from IPC client")
      }
      close(self.fd)
    }
  }
}
