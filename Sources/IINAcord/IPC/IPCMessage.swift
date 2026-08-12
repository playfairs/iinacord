import Foundation

enum IPCMessageType: String, Codable {
  case playback
}

struct IPCMessage: Codable {
  let type: IPCMessageType
  let title: String?
  let url: String?
  let position: TimeInterval?
  let duration: TimeInterval?
  let paused: Bool?
  let idle: Bool?
}
