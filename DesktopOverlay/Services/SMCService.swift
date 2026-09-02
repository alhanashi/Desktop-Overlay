import Foundation
import IOKit

/// Minimal **read-only** SMC client for CPU temperature and fan RPM.
///
/// ⚠️ The SMC key names and value encodings used here are **not documented by
/// Apple** — they are community-reverse-engineered (the same approach iStat
/// Menus, TG Pro and Stats use). This module is:
///   * optional and **disabled by default** (thermal state remains the default);
///   * privilege-free — it needs no root, and does not touch SIP or Gatekeeper;
///   * fail-safe — any unreadable key yields `nil`, never a crash.
///
/// On Apple Silicon the classic `TC0x` / `F0Ac` keys are absent, so
/// `isAvailable` is `false` and the dependent metrics report "unavailable".
///
/// The kernel's `SMCKeyData_t` is a fixed 80-byte structure. Rather than mirror
/// its nested-struct layout in Swift (whose padding does not match), it is
/// addressed here as a raw 80-byte buffer with explicit field offsets.
final class SMCService {

    static let shared = SMCService()

    private let lock = NSLock()
    private var connection: io_connect_t = 0
    private var opened = false
    private var resolvedTempKey = false
    private var cachedTempKey: UInt32?

    // SMC user-client selector + command bytes (community-known).
    private let kSMCKernelIndex: UInt32 = 2
    private let kSMCReadBytes: UInt8 = 5
    private let kSMCReadKeyInfo: UInt8 = 9

    // SMCKeyData_t byte layout.
    private let paramSize = 80
    private let offKey = 0            // UInt32
    private let offKeyInfoDataSize = 28   // UInt32
    private let offKeyInfoDataType = 32   // UInt32
    private let offResult = 40        // UInt8
    private let offData8 = 42         // UInt8
    private let offBytes = 48         // 32 bytes

    private let tempKeyCandidates = ["TC0D", "TC0P", "TCXC", "TC0E", "TC0F", "TCAD", "TCHP", "Th0H", "TG0P"]
    private let fanKeyCandidates = ["F0Ac", "F1Ac", "F2Ac"]

    private init() {}

    deinit {
        if opened { IOServiceClose(connection) }
    }

    // MARK: - Public

    var isAvailable: Bool {
        lock.lock(); defer { lock.unlock() }
        ensureOpen()
        return resolveTempKeyLocked() != nil
    }

    func cpuTemperature() -> Double? {
        lock.lock(); defer { lock.unlock() }
        ensureOpen()
        guard opened, let key = resolveTempKeyLocked(),
              let value = readValueLocked(key: key), value > 0, value < 125 else { return nil }
        return value
    }

    /// Highest RPM across the fans, or `nil` if no fan key is readable.
    func fanRPM() -> Double? {
        lock.lock(); defer { lock.unlock() }
        ensureOpen()
        guard opened else { return nil }
        var best: Double?
        for name in fanKeyCandidates {
            if let value = readValueLocked(key: Self.fourCharCode(name)), value >= 0, value < 12_000 {
                best = Swift.max(best ?? 0, value)
            }
        }
        return best
    }

    // MARK: - Connection

    private func ensureOpen() {
        guard !opened else { return }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        opened = (IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess)
    }

    private func resolveTempKeyLocked() -> UInt32? {
        if resolvedTempKey { return cachedTempKey }
        resolvedTempKey = true
        guard opened else { return nil }
        for name in tempKeyCandidates {
            let key = Self.fourCharCode(name)
            if let value = readValueLocked(key: key), value > 0, value < 125 {
                cachedTempKey = key
                return key
            }
        }
        return nil
    }

    // MARK: - SMC protocol

    private func readValueLocked(key: UInt32) -> Double? {
        // 1. Ask for the key's size + type.
        var info = [UInt8](repeating: 0, count: paramSize)
        setU32(&info, offKey, key)
        info[offData8] = kSMCReadKeyInfo
        guard var out = callLocked(info), out[offResult] == 0 else { return nil }

        let dataSize = getU32(out, offKeyInfoDataSize)
        let dataType = getU32(out, offKeyInfoDataType)
        guard dataSize > 0, dataSize <= 32 else { return nil }

        // 2. Read the bytes.
        var read = [UInt8](repeating: 0, count: paramSize)
        setU32(&read, offKey, key)
        setU32(&read, offKeyInfoDataSize, dataSize)
        read[offData8] = kSMCReadBytes
        guard let bytesOut = callLocked(read), bytesOut[offResult] == 0 else { return nil }
        out = bytesOut

        let payload = Array(out[offBytes ..< (offBytes + Int(dataSize))])
        return Self.decode(type: dataType, bytes: payload)
    }

    private func callLocked(_ input: [UInt8]) -> [UInt8]? {
        var output = [UInt8](repeating: 0, count: paramSize)
        var outputSize = paramSize
        let result = input.withUnsafeBytes { inPtr in
            output.withUnsafeMutableBytes { outPtr in
                IOConnectCallStructMethod(
                    connection, kSMCKernelIndex,
                    inPtr.baseAddress, paramSize,
                    outPtr.baseAddress, &outputSize
                )
            }
        }
        return result == kIOReturnSuccess ? output : nil
    }

    // MARK: - Encoding helpers

    private func setU32(_ buffer: inout [UInt8], _ offset: Int, _ value: UInt32) {
        buffer[offset]     = UInt8(value & 0xff)
        buffer[offset + 1] = UInt8((value >> 8) & 0xff)
        buffer[offset + 2] = UInt8((value >> 16) & 0xff)
        buffer[offset + 3] = UInt8((value >> 24) & 0xff)
    }

    private func getU32(_ buffer: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(buffer[offset])
            | (UInt32(buffer[offset + 1]) << 8)
            | (UInt32(buffer[offset + 2]) << 16)
            | (UInt32(buffer[offset + 3]) << 24)
    }

    // MARK: - Value decoding

    /// Internal (not private) so the reverse-engineered decoders are unit-tested.
    static func decode(type: UInt32, bytes: [UInt8]) -> Double? {
        switch typeString(type) {
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int8(bitPattern: bytes[0])) + Double(bytes[1]) / 256.0
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 4.0
        case "flt":
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            return Double(Float(bitPattern: raw))
        case "ui8":
            return bytes.first.map(Double.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        default:
            guard bytes.count >= 2 else { return nil }
            let guess = Double(Int8(bitPattern: bytes[0])) + Double(bytes[1]) / 256.0
            return (guess > 0 && guess < 125) ? guess : nil
        }
    }

    static func fourCharCode(_ string: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in string.utf8.prefix(4) { result = (result << 8) | UInt32(byte) }
        return result
    }

    static func typeString(_ code: UInt32) -> String {
        let chars = [UInt8((code >> 24) & 0xff), UInt8((code >> 16) & 0xff),
                     UInt8((code >> 8) & 0xff), UInt8(code & 0xff)]
        return String(bytes: chars.filter { $0 != 0 && $0 != 0x20 }, encoding: .ascii) ?? ""
    }
}
