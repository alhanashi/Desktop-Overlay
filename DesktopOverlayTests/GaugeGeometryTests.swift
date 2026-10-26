import XCTest
@testable import DesktopOverlay

final class GaugeGeometryTests: XCTestCase {

    func testSweepForKeyValues() {
        XCTAssertEqual(GaugeGeometry.sweepDegrees(for: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(GaugeGeometry.sweepDegrees(for: 0.5), 135, accuracy: 0.0001)
        XCTAssertEqual(GaugeGeometry.sweepDegrees(for: 1), 270, accuracy: 0.0001)
    }

    func testOutOfRangeAndNonFiniteValuesAreClamped() {
        XCTAssertEqual(GaugeGeometry.sweepDegrees(for: -3), 0, accuracy: 0.0001)
        XCTAssertEqual(GaugeGeometry.sweepDegrees(for: 7), 270, accuracy: 0.0001)
        XCTAssertEqual(GaugeGeometry.sweepDegrees(for: .nan), 0, accuracy: 0.0001)
        XCTAssertEqual(GaugeGeometry.sweepDegrees(for: .infinity), 0, accuracy: 0.0001)
    }

    func testArcStartsAtBottomLeft() {
        let points = GaugeGeometry.arcPoints(center: CGPoint(x: 10, y: 10), radius: 10, sweep: 270)
        let first = points[0]
        // 135° clockwise from 3 o'clock, y down → bottom-left of the circle.
        XCTAssertEqual(first.x, 10 - 10 * 0.70710678, accuracy: 0.001)
        XCTAssertEqual(first.y, 10 + 10 * 0.70710678, accuracy: 0.001)
    }

    func testFullArcEndsAtBottomRight() {
        let points = GaugeGeometry.arcPoints(center: CGPoint(x: 10, y: 10), radius: 10, sweep: 270)
        let last = points[points.count - 1]
        XCTAssertEqual(last.x, 10 + 10 * 0.70710678, accuracy: 0.001)
        XCTAssertEqual(last.y, 10 + 10 * 0.70710678, accuracy: 0.001)
    }

    func testHalfArcEndsAtTop() {
        let points = GaugeGeometry.arcPoints(center: CGPoint(x: 10, y: 10), radius: 10, sweep: 135)
        let last = points[points.count - 1]
        // 135° + 135° = 270° → straight up on screen (y smaller).
        XCTAssertEqual(last.x, 10, accuracy: 0.001)
        XCTAssertEqual(last.y, 0, accuracy: 0.001)
    }

    func testTinySweepStillProducesADot() {
        XCTAssertGreaterThanOrEqual(
            GaugeGeometry.arcPoints(center: .zero, radius: 5, sweep: 0.5).count, 2)
    }
}
