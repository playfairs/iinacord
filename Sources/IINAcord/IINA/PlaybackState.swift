import Foundation

struct PlaybackState: Equatable {
  let title: String
  let position: TimeInterval
  let duration: TimeInterval
  let paused: Bool
  let idle: Bool

  init(title: String, position: TimeInterval, duration: TimeInterval, paused: Bool, idle: Bool) {
    self.title = title
    self.position = position
    self.duration = duration
    self.paused = paused
    self.idle = idle
  }

  init?(from message: IPCMessage) {
    guard message.type == .playback else { return nil }
    guard let title = message.title else { return nil }
    let position = message.position ?? 0
    let duration = message.duration ?? 0
    let paused = message.paused ?? false
    let idle = message.idle ?? false
    self.init(title: title, position: position, duration: duration, paused: paused, idle: idle)
  }
}
