import Foundation

/// Pure helpers for turning monotonically-increasing byte counters into a
/// per-second rate. Shared by the Disk and Network metrics and unit-tested
/// directly (spec §28).
enum RateCalculator {

    /// Bytes per second between two cumulative counter readings.
    ///
    /// Returns `0` when the interval is non-positive, or when the counter went
    /// backwards (a device reset, an unplugged interface, or a 32-bit wrap) —
    /// one dropped sample is preferable to a spurious spike.
    static func bytesPerSecond(previous: UInt64, current: UInt64, interval: TimeInterval) -> Double {
        guard interval > 0 else { return 0 }
        guard current >= previous else { return 0 }
        return Double(current - previous) / interval
    }

    /// Non-negative delta between two unsigned counters (`0` if it went backwards).
    static func delta(previous: UInt64, current: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }
}
