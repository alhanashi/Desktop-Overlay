import Foundation

/// Aggregate disk read / write throughput across all block-storage drivers
/// (spec §5).
final class DiskMetric: SystemMetric {
    let id: MetricID = .disk

    private var previous: (read: UInt64, write: UInt64)?
    private var previousDate: Date?
    private var graphMax = DecayingMax(decay: 0.9, floor: 1_000_000) // ~1 MB/s floor

    init() {
        previous = SystemMetricsService.diskIOBytes()
        previousDate = Date()
    }

    func sample(interval: TimeInterval) -> MetricReading {
        guard let current = SystemMetricsService.diskIOBytes() else { return .unavailable }
        let now = Date()
        defer { previous = current; previousDate = now }

        guard let previous, let previousDate else { return .pending }
        let elapsed = now.timeIntervalSince(previousDate)

        let read = RateCalculator.bytesPerSecond(previous: previous.read, current: current.read, interval: elapsed)
        let write = RateCalculator.bytesPerSecond(previous: previous.write, current: current.write, interval: elapsed)

        return MetricReading(
            primary: .bytesPerSecond(read + write),
            components: [
                "read": .bytesPerSecond(read),
                "write": .bytesPerSecond(write),
            ],
            graphSample: graphMax.normalise(read + write)
        )
    }
}
