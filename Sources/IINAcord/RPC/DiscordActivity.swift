import Foundation

struct DiscordActivity: Equatable {
  let details: String
  let state: String
  let start: Date?
  let end: Date?

  init(details: String, state: String, start: Date?, end: Date?) {
    self.details = details
    self.state = state
    self.start = start
    self.end = end
  }

  static func fromPlayback(_ playback: PlaybackState) -> DiscordActivity {
    if playback.idle || playback.duration <= 0 {
      return DiscordActivity(details: playback.title, state: "Idle", start: nil, end: nil)
    }
    if playback.paused {
      return DiscordActivity(details: playback.title, state: "Paused", start: nil, end: nil)
    }
    let now = Date()
    let start = Date(timeIntervalSince1970: now.timeIntervalSince1970 - playback.position)
    let end = Date(timeIntervalSince1970: start.timeIntervalSince1970 + playback.duration)
    return DiscordActivity(
      details: playback.title, state: "Playing on IINA", start: start, end: end)
  }

  init(from playback: PlaybackState) {
    self = DiscordActivity.fromPlayback(playback)
  }
}
