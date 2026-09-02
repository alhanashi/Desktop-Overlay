import XCTest
@testable import DesktopOverlay

final class OverlayGeometryTests: XCTestCase {

    private let mainScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let secondScreen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)

    func testFrameFullyOnScreenIsUnchanged() {
        let frame = CGRect(x: 100, y: 100, width: 220, height: 140)
        let result = OverlayGeometry.clampedFrame(frame, into: [mainScreen], primary: mainScreen)
        XCTAssertEqual(result, frame)
    }

    func testFrameOnSecondScreenIsKept() {
        let frame = CGRect(x: 1600, y: 200, width: 220, height: 140)
        let result = OverlayGeometry.clampedFrame(frame, into: [mainScreen, secondScreen], primary: mainScreen)
        XCTAssertEqual(result, frame)
    }

    func testOffscreenFrameRecentersOnPrimary() {
        let frame = CGRect(x: 5000, y: 5000, width: 220, height: 140)
        let result = OverlayGeometry.clampedFrame(frame, into: [mainScreen], primary: mainScreen)
        XCTAssertTrue(OverlayGeometry.isFrameVisible(result, in: [mainScreen]))
        XCTAssertEqual(result.midX, mainScreen.midX, accuracy: 1)
        XCTAssertEqual(result.midY, mainScreen.midY, accuracy: 1)
    }

    func testDisconnectedSecondScreenFallsBackToPrimary() {
        // Frame was on the second screen, which is now gone.
        let frame = CGRect(x: 1600, y: 200, width: 220, height: 140)
        let result = OverlayGeometry.clampedFrame(frame, into: [mainScreen], primary: mainScreen)
        XCTAssertTrue(OverlayGeometry.isFrameVisible(result, in: [mainScreen]))
    }

    func testTinySliverOnScreenCountsAsOffscreen() {
        // Only 10pt visible — below the 40pt threshold.
        let frame = CGRect(x: -210, y: 100, width: 220, height: 140)
        XCTAssertFalse(OverlayGeometry.isFrameVisible(frame, in: [mainScreen]))
    }

    func testOversizedOffscreenFrameIsClampedToMaxSize() {
        let frame = CGRect(x: -9000, y: -9000, width: 5000, height: 5000)
        let result = OverlayGeometry.clampedFrame(frame, into: [mainScreen], primary: mainScreen)
        XCTAssertLessThanOrEqual(result.width, OverlayGeometry.maxSize.width)
        XCTAssertLessThanOrEqual(result.height, OverlayGeometry.maxSize.height)
    }

    func testDefaultFrameIsCenteredAndDefaultSized() {
        let result = OverlayGeometry.defaultFrame(on: mainScreen)
        XCTAssertEqual(result.size, OverlayGeometry.defaultSize)
        XCTAssertEqual(result.midX, mainScreen.midX, accuracy: 1)
        XCTAssertEqual(result.midY, mainScreen.midY, accuracy: 1)
    }
}
