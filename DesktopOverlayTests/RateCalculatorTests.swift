import XCTest
@testable import DesktopOverlay

final class RateCalculatorTests: XCTestCase {

    func testSteadyRate() {
        let rate = RateCalculator.bytesPerSecond(previous: 1_000, current: 3_000, interval: 2)
        XCTAssertEqual(rate, 1_000, accuracy: 0.001)
    }

    func testSubSecondInterval() {
        let rate = RateCalculator.bytesPerSecond(previous: 0, current: 500, interval: 0.5)
        XCTAssertEqual(rate, 1_000, accuracy: 0.001)
    }

    func testZeroIntervalReturnsZero() {
        XCTAssertEqual(RateCalculator.bytesPerSecond(previous: 0, current: 999, interval: 0), 0)
    }

    func testNegativeIntervalReturnsZero() {
        XCTAssertEqual(RateCalculator.bytesPerSecond(previous: 0, current: 999, interval: -1), 0)
    }

    func testCounterResetOrWrapReturnsZero() {
        // current < previous → treated as a reset, no spike.
        XCTAssertEqual(RateCalculator.bytesPerSecond(previous: 10_000, current: 5, interval: 1), 0)
    }

    func testDeltaHelper() {
        XCTAssertEqual(RateCalculator.delta(previous: 5, current: 20), 15)
        XCTAssertEqual(RateCalculator.delta(previous: 20, current: 5), 0)
    }
}
