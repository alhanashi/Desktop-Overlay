import XCTest
@testable import DesktopOverlay

final class RingBufferTests: XCTestCase {

    func testAppendUnderCapacityKeepsOrder() {
        var buffer = RingBuffer<Int>(capacity: 5)
        [1, 2, 3].forEach { buffer.append($0) }
        XCTAssertEqual(buffer.values, [1, 2, 3])
        XCTAssertEqual(buffer.count, 3)
        XCTAssertFalse(buffer.isFull)
    }

    func testOverwritesOldestWhenFull() {
        var buffer = RingBuffer<Int>(capacity: 3)
        [1, 2, 3, 4, 5].forEach { buffer.append($0) }
        XCTAssertEqual(buffer.values, [3, 4, 5])
        XCTAssertEqual(buffer.count, 3)
        XCTAssertTrue(buffer.isFull)
    }

    func testExactlyFull() {
        var buffer = RingBuffer<Int>(capacity: 3)
        [10, 20, 30].forEach { buffer.append($0) }
        XCTAssertEqual(buffer.values, [10, 20, 30])
    }

    func testRemoveAll() {
        var buffer = RingBuffer<Int>(capacity: 3)
        [1, 2, 3, 4].forEach { buffer.append($0) }
        buffer.removeAll()
        XCTAssertEqual(buffer.values, [])
        XCTAssertEqual(buffer.count, 0)
        buffer.append(9)
        XCTAssertEqual(buffer.values, [9])
    }

    func testWrapMultipleTimes() {
        var buffer = RingBuffer<Int>(capacity: 2)
        (1...10).forEach { buffer.append($0) }
        XCTAssertEqual(buffer.values, [9, 10])
    }
}
