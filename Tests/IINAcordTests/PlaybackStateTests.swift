import XCTest

@testable import IINAcord

final class PlaybackStateTests: XCTestCase {
  func testPlaybackInit() {
    let msg = IPCMessage(
      type: .playback, title: "Song", url: nil, position: 30, duration: 120, paused: false,
      idle: false)
    let state = PlaybackState(from: msg)
    XCTAssertNotNil(state)
    XCTAssertEqual(state?.title, "Song")
  }
}
