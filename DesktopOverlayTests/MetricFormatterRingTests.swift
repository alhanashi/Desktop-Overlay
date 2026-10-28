import XCTest
@testable import DesktopOverlay

final class MetricFormatterRingTests: XCTestCase {

    func testUnavailableReadingShowsDash() {
        let centre = MetricFormatter.ringCenter(for: .cpu, reading: .unavailable)
        XCTAssertEqual(centre.value, MetricFormatter.unavailable)
        XCTAssertNil(centre.unit)
        let none = MetricFormatter.ringCenter(for: .cpu, reading: nil)
        XCTAssertEqual(none.value, MetricFormatter.unavailable)
    }

    func testPercentHasNoUnitLine() {
        let reading = MetricReading(primary: .percent(42), graphSample: 0.42)
        let centre = MetricFormatter.ringCenter(for: .cpu, reading: reading)
        XCTAssertEqual(centre.value, "42%")
        XCTAssertNil(centre.unit)
    }

    func testRateSplitsValueAndUnit() {
        let reading = MetricReading(primary: .bytesPerSecond(800 * 1024))
        let centre = MetricFormatter.ringCenter(for: .network, reading: reading)
        XCTAssertEqual(centre.value, "800")
        XCTAssertEqual(centre.unit, "KB/s")

        let slow = MetricFormatter.ringCenter(for: .disk, reading: MetricReading(primary: .bytesPerSecond(512)))
        XCTAssertEqual(slow.value, "512")
        XCTAssertEqual(slow.unit, "B/s")

        let fast = MetricFormatter.ringCenter(for: .disk,
                                              reading: MetricReading(primary: .bytesPerSecond(2.5 * 1024 * 1024)))
        XCTAssertEqual(fast.value, "2.5")
        XCTAssertEqual(fast.unit, "MB/s")
    }

    func testFanShowsRpm() {
        let centre = MetricFormatter.ringCenter(for: .fan, reading: MetricReading(primary: .rpm(1824.6)))
        XCTAssertEqual(centre.value, "1825")
        XCTAssertEqual(centre.unit, "rpm")
    }

    func testDiskAndNetworkDetailAreTwoDirectionLines() {
        let reading = MetricReading(
            primary: .bytesPerSecond(100),
            components: ["down": .bytesPerSecond(799 * 1024), "up": .bytesPerSecond(8 * 1024)]
        )
        let detail = MetricFormatter.ringDetail(for: .network, reading: reading)
        XCTAssertEqual(detail.count, 2)
        XCTAssertTrue(detail[0].hasPrefix("↓"))
        XCTAssertTrue(detail[1].hasPrefix("↑"))

        let disk = MetricReading(
            primary: .bytesPerSecond(100),
            components: ["read": .bytesPerSecond(1024), "write": .bytesPerSecond(2048)]
        )
        XCTAssertEqual(MetricFormatter.ringDetail(for: .disk, reading: disk).count, 2)
    }

    func testDetailIsEmptyWithoutData() {
        XCTAssertTrue(MetricFormatter.ringDetail(for: .network, reading: nil).isEmpty)
        XCTAssertTrue(MetricFormatter.ringDetail(for: .network, reading: MetricReading(primary: .bytesPerSecond(1))).isEmpty)
    }
}
