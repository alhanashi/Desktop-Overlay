import Foundation

/// Selected fields from `vm_statistics64`, in pages.
struct MemorySample: Equatable, Sendable {
    var active: UInt64
    var wired: UInt64
    var compressed: UInt64
    var free: UInt64
    var inactive: UInt64
}

/// Derived memory figures.
struct MemoryUsage: Equatable, Sendable {
    var usedBytes: UInt64
    var availableBytes: UInt64
    var totalBytes: UInt64
    var usedPercent: Double
}

/// Overall memory pressure, mirroring `kern.memorystatus_vm_pressure_level`
/// (spec §5). Not a color alone — the label is always shown too (spec §26).
enum MemoryPressure: Int, Sendable {
    case normal = 1
    case warning = 2
    case critical = 4

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

/// Pure memory math, unit-tested with synthetic `vm_statistics64` values (spec §28).
enum MemoryCalculator {

    /// "Used" follows Activity Monitor's model closely enough for a glanceable
    /// readout: resident app pages + wired (kernel) + compressor pool.
    static func usage(sample: MemorySample, pageSize: UInt64, physical: UInt64) -> MemoryUsage {
        let used = (sample.active &+ sample.wired &+ sample.compressed) &* pageSize
        let available = physical > used ? physical - used : 0
        let percent = physical > 0
            ? (Double(used) / Double(physical) * 100).clamped(to: 0...100)
            : 0
        return MemoryUsage(usedBytes: used,
                           availableBytes: available,
                           totalBytes: physical,
                           usedPercent: percent)
    }
}
