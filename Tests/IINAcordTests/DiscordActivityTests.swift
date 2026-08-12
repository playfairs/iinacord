import XCTest

@testable import IINAcord

final class DiscordActivityTests: XCTestCase {
  func testTimestamps() {
    let playback = PlaybackState(
      title: "Movie", position: 60, duration: 3600, paused: false, idle: false)
    let activity = DiscordActivity(from: playback)
    XCTAssertNotNil(activity.start)
    XCTAssertNotNil(activity.end)
    XCTAssertEqual(activity.details, "Movie")
  }
}
