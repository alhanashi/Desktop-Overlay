import XCTest
@testable import DesktopOverlay

final class MemoryCalculatorTests: XCTestCase {

    private let pageSize: UInt64 = 4096

    func testHalfUsed() {
        // 1000 pages used out of 2000 pages of physical memory.
        let sample = MemorySample(active: 600, wired: 300, compressed: 100, free: 1000, inactive: 0)
        let physical = 2000 * pageSize
        let usage = MemoryCalculator.usage(sample: sample, pageSize: pageSize, physical: physical)
        XCTAssertEqual(usage.usedBytes, 1000 * pageSize)
        XCTAssertEqual(usage.availableBytes, 1000 * pageSize)
        XCTAssertEqual(usage.usedPercent, 50, accuracy: 0.001)
    }

    func testUsedNeverExceedsHundredPercent() {
        let sample = MemorySample(active: 5000, wired: 5000, compressed: 5000, free: 0, inactive: 0)
        let physical = 1000 * pageSize
        let usage = MemoryCalculator.usage(sample: sample, pageSize: pageSize, physical: physical)
        XCTAssertLessThanOrEqual(usage.usedPercent, 100)
        XCTAssertEqual(usage.availableBytes, 0)
    }

    func testZeroPhysicalDoesNotDivideByZero() {
        let sample = MemorySample(active: 1, wired: 1, compressed: 1, free: 0, inactive: 0)
        let usage = MemoryCalculator.usage(sample: sample, pageSize: pageSize, physical: 0)
        XCTAssertEqual(usage.usedPercent, 0)
    }

    func testPressureLabels() {
        XCTAssertEqual(MemoryPressure.normal.label, "Normal")
        XCTAssertEqual(MemoryPressure.warning.label, "Warning")
        XCTAssertEqual(MemoryPressure.critical.label, "Critical")
    }
}
