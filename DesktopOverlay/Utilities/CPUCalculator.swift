import Foundation

/// Cumulative CPU tick counters, as reported by `HOST_CPU_LOAD_INFO`.
struct CPUTicks: Equatable, Sendable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64
}

/// CPU usage over an interval, as percentages that sum to ~100.
struct CPUUsage: Equatable, Sendable {
    var user: Double
    var system: Double
    var idle: Double
    /// Total non-idle usage (`100 - idle`).
    var total: Double
}

/// Pure CPU-usage math, unit-tested with synthetic tick deltas (spec §28).
enum CPUCalculator {

    static func usage(from previous: CPUTicks, to current: CPUTicks) -> CPUUsage {
        let dUser = Double(RateCalculator.delta(previous: previous.user, current: current.user))
        let dSystem = Double(RateCalculator.delta(previous: previous.system, current: current.system))
        let dIdle = Double(RateCalculator.delta(previous: previous.idle, current: current.idle))
        let dNice = Double(RateCalculator.delta(previous: previous.nice, current: current.nice))

        let totalTicks = dUser + dSystem + dIdle + dNice
        guard totalTicks > 0 else {
            return CPUUsage(user: 0, system: 0, idle: 100, total: 0)
        }

        let user = (dUser + dNice) / totalTicks * 100
        let system = dSystem / totalTicks * 100
        let idle = dIdle / totalTicks * 100
        return CPUUsage(user: user,
                        system: system,
                        idle: idle,
                        total: (100 - idle).clamped(to: 0...100))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
