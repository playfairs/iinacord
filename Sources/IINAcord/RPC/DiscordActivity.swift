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

  private static func formattedDetails(for title: String) -> String {
    let withoutExtension: String
    if let lastDot = title.lastIndex(of: "."), lastDot > title.startIndex {
      let namePart = String(title[..<lastDot])
      let suffix = String(title[title.index(after: lastDot)...])
      let removableExtensions = ["mkv", "mp4", "mov", "avi", "mp3", "m4a", "wav", "flac", "m4v", "webm", "ts", "m2ts", "srt", "ass", "sub"]
      if removableExtensions.contains(suffix.lowercased()) {
        withoutExtension = namePart
      } else {
        withoutExtension = title
      }
    } else {
      withoutExtension = title
    }

    let simple = withoutExtension
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: ".", with: " ")
      .split(whereSeparator: { $0.isWhitespace })
      .map { token in
        guard !token.isEmpty else { return "" }
        return token.prefix(1).uppercased() + token.dropFirst().lowercased()
      }
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return simple.isEmpty ? "IINA" : simple
  }

  static func fromPlayback(_ playback: PlaybackState) -> DiscordActivity {
    let details = formattedDetails(for: playback.title)
    if playback.idle || playback.duration <= 0 {
      return DiscordActivity(details: details, state: "Idle", start: nil, end: nil)
    }
    if playback.paused {
      return DiscordActivity(details: details, state: "Paused", start: nil, end: nil)
    }
    let now = Date()
    let start = Date(timeIntervalSince1970: now.timeIntervalSince1970 - playback.position)
    let end = Date(timeIntervalSince1970: start.timeIntervalSince1970 + playback.duration)
    return DiscordActivity(
      details: details, state: "Playing on IINA", start: start, end: end)
  }

  init(from playback: PlaybackState) {
    self = DiscordActivity.fromPlayback(playback)
  }
}