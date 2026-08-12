import XCTest

@testable import IINAcord

final class IPCMessageTests: XCTestCase {
  func testEncodeDecode() throws {
    let msg = IPCMessage(
      type: .playback, title: "Test", url: nil, position: 10.5, duration: 100, paused: false,
      idle: false)
    let data = try JSONEncoder().encode(msg)
    let decoded = try JSONDecoder().decode(IPCMessage.self, from: data)
    XCTAssertEqual(decoded.type, .playback)
    XCTAssertEqual(decoded.title, "Test")
    XCTAssertEqual(decoded.position, 10.5)
  }
}
