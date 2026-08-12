import Foundation

final class IPCServer {
  private let path: String
  private var listenFd: Int32 = -1
  private var isRunning = false
  var onMessage: ((IPCMessage) -> Void)?
  var onLog: ((String) -> Void)?

  init(path: String) {
    self.path = path
  }

  func start() {
    stop()
    DispatchQueue.global(qos: .background).async { [weak self] in
      guard let self = self else { return }
      self.onLog?("opening socket at \(self.path)")
      let fd = socket(AF_UNIX, SOCK_STREAM, 0)
      guard fd >= 0 else {
        self.onLog?("socket creation failed: \(String(cString: strerror(errno)))")
        return
      }
      self.listenFd = fd
      var addr = sockaddr_un()
      addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
      addr.sun_family = sa_family_t(AF_UNIX)
      let pathBytes = self.path.utf8CString
      self.path.utf8CString.withUnsafeBufferPointer { bytes in
        withUnsafeMutableBytes(of: &addr.sun_path) { dest in
          let count = min(dest.count, bytes.count)
          dest.baseAddress?.copyMemory(from: bytes.baseAddress!, byteCount: count)
        }
      }
      unlink(self.path)
      let pathLength = min(pathBytes.count, MemoryLayout.size(ofValue: addr.sun_path))
      let len = socklen_t(
        MemoryLayout.size(ofValue: addr.sun_len) + MemoryLayout.size(ofValue: addr.sun_family)
          + pathLength)
      let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
          bind(fd, sockaddrPtr, len)
        }
      }
      guard bindResult >= 0 else {
        self.onLog?("socket bind failed: \(String(cString: strerror(errno)))")
        close(fd)
        return
      }
      guard listen(fd, 5) >= 0 else {
        self.onLog?("socket listen failed: \(String(cString: strerror(errno)))")
        close(fd)
        return
      }
      self.onLog?("socket listening")
      self.isRunning = true
      while self.isRunning {
        var clientAddr = sockaddr()
        var clientLen: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
        let clientFd = accept(fd, &clientAddr, &clientLen)
        if clientFd >= 0 {
          self.onLog?("accepted client connection")
          let conn = IPCConnection(fd: clientFd)
          conn.onLog = self.onLog
          conn.onMessage = { [weak self] msg in
            self?.onMessage?(msg)
          }
          conn.start()
        } else if self.isRunning {
          self.onLog?("accept failed: \(String(cString: strerror(errno)))")
        }
      }
      close(fd)
    }
  }

  func stop() {
    isRunning = false
    if listenFd >= 0 {
      close(listenFd)
      listenFd = -1
    }
    unlink(path)
  }
}
