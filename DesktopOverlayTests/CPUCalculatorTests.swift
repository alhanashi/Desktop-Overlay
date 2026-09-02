import XCTest
@testable import DesktopOverlay

final class CPUCalculatorTests: XCTestCase {

    func testFullyIdle() {
        let previous = CPUTicks(user: 100, system: 50, idle: 1000, nice: 0)
        let current = CPUTicks(user: 100, system: 50, idle: 1100, nice: 0)
        let usage = CPUCalculator.usage(from: previous, to: current)
        XCTAssertEqual(usage.idle, 100, accuracy: 0.001)
        XCTAssertEqual(usage.total, 0, accuracy: 0.001)
        XCTAssertEqual(usage.user, 0, accuracy: 0.001)
    }

    func testFullyBusyUser() {
        let previous = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let current = CPUTicks(user: 200, system: 0, idle: 0, nice: 0)
        let usage = CPUCalculator.usage(from: previous, to: current)
        XCTAssertEqual(usage.user, 100, accuracy: 0.001)
        XCTAssertEqual(usage.total, 100, accuracy: 0.001)
    }

    func testMixedLoad() {
        let previous = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let current = CPUTicks(user: 20, system: 10, idle: 70, nice: 0)
        let usage = CPUCalculator.usage(from: previous, to: current)
        XCTAssertEqual(usage.user, 20, accuracy: 0.001)
        XCTAssertEqual(usage.system, 10, accuracy: 0.001)
        XCTAssertEqual(usage.idle, 70, accuracy: 0.001)
        XCTAssertEqual(usage.total, 30, accuracy: 0.001)
    }

    func testNiceCountsAsUser() {
        let previous = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let current = CPUTicks(user: 10, system: 0, idle: 80, nice: 10)
        let usage = CPUCalculator.usage(from: previous, to: current)
        XCTAssertEqual(usage.user, 20, accuracy: 0.001)
        XCTAssertEqual(usage.total, 20, accuracy: 0.001)
    }

    func testNoDeltaIsTreatedAsIdle() {
        let ticks = CPUTicks(user: 5, system: 5, idle: 5, nice: 5)
        let usage = CPUCalculator.usage(from: ticks, to: ticks)
        XCTAssertEqual(usage.total, 0, accuracy: 0.001)
        XCTAssertEqual(usage.idle, 100, accuracy: 0.001)
    }

    func testCounterGoingBackwardsDoesNotCrashOrExplode() {
        let previous = CPUTicks(user: 1000, system: 1000, idle: 1000, nice: 0)
        let current = CPUTicks(user: 10, system: 10, idle: 2000, nice: 0)
        let usage = CPUCalculator.usage(from: previous, to: current)
        XCTAssertGreaterThanOrEqual(usage.total, 0)
        XCTAssertLessThanOrEqual(usage.total, 100)
    }
}
