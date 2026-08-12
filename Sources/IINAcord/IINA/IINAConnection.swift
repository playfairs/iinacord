import Foundation

final class IINAConnection {
  private let socketPath: String

  init(socketPath: String = "/tmp/iinacord.sock") {
    self.socketPath = socketPath
  }

  func send(message: IPCMessage) -> Bool {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(message) else { return false }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let _ = socketPath.withCString { cstr in
      withUnsafeMutableBytes(of: &addr.sun_path) { dest in
        let count = min(strlen(cstr) + 1, dest.count)
        memcpy(dest.baseAddress, cstr, count)
      }
    }
    let len = socklen_t(MemoryLayout<sockaddr_un>.size)
    var connected = false
    withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        if connect(fd, sockaddrPtr, len) == 0 {
          connected = true
        }
      }
    }
    if !connected {
      close(fd)
      return false
    }
    _ = data.withUnsafeBytes { ptr in
      write(fd, ptr.baseAddress, ptr.count)
    }
    close(fd)
    return true
  }
}
