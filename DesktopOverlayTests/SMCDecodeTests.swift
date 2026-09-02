import XCTest
@testable import DesktopOverlay

/// Covers the reverse-engineered SMC value decoders (the risky part of the
/// optional sensor module).
final class SMCDecodeTests: XCTestCase {

    private func code(_ s: String) -> UInt32 { SMCService.fourCharCode(s) }

    func testSP78Temperature() {
        // 0x31 = 49, fraction 0x70/256 = 0.4375  → 49.4375 °C
        let value = SMCService.decode(type: code("sp78"), bytes: [0x31, 0x70])
        XCTAssertEqual(value ?? 0, 49.4375, accuracy: 0.0001)
    }

    func testSP78NegativeTemperature() {
        // 0xFF = -1 integer part
        let value = SMCService.decode(type: code("sp78"), bytes: [0xFF, 0x80])
        XCTAssertEqual(value ?? 0, -0.5, accuracy: 0.0001)
    }

    func testFPE2FanRPM() {
        // (0x1C << 8 | 0xA8) = 7336 ; /4 = 1834 rpm
        let value = SMCService.decode(type: code("fpe2"), bytes: [0x1C, 0xA8])
        XCTAssertEqual(value ?? 0, 1834, accuracy: 0.5)
    }

    func testFloatFanRPM() {
        // little-endian IEEE-754 for 1834.0
        var bits = Float(1834).bitPattern
        let bytes = withUnsafeBytes(of: &bits) { Array($0) }
        let value = SMCService.decode(type: code("flt "), bytes: bytes)
        XCTAssertEqual(value ?? 0, 1834, accuracy: 0.01)
    }

    func testUInt8Count() {
        XCTAssertEqual(SMCService.decode(type: code("ui8 "), bytes: [2]), 2)
    }

    func testTypeStringTrimsSpaces() {
        XCTAssertEqual(SMCService.typeString(code("flt ")), "flt")
        XCTAssertEqual(SMCService.typeString(code("sp78")), "sp78")
    }

    func testShortBufferIsRejected() {
        XCTAssertNil(SMCService.decode(type: code("flt "), bytes: [0x00]))
    }
}
