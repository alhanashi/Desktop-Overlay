import Foundation

/// Aggregate network download / upload throughput across physical interfaces
/// (loopback excluded) (spec §5).
final class NetworkMetric: SystemMetric {
    let id: MetricID = .network

    private var previous: (received: UInt64, sent: UInt64)?
    private var previousDate: Date?
    private var graphMax = DecayingMax(decay: 0.9, floor: 500_000) // ~0.5 MB/s floor

    init() {
        previous = SystemMetricsService.networkBytes()
        previousDate = Date()
    }

    func sample(interval: TimeInterval) -> MetricReading {
        guard let current = SystemMetricsService.networkBytes() else { return .unavailable }
        let now = Date()
        defer { previous = current; previousDate = now }

        guard let previous, let previousDate else { return .pending }
        let elapsed = now.timeIntervalSince(previousDate)

        let down = RateCalculator.bytesPerSecond(previous: previous.received, current: current.received, interval: elapsed)
        let up = RateCalculator.bytesPerSecond(previous: previous.sent, current: current.sent, interval: elapsed)

        return MetricReading(
            primary: .bytesPerSecond(down + up),
            components: [
                "down": .bytesPerSecond(down),
                "up": .bytesPerSecond(up),
            ],
            graphSample: graphMax.normalise(down + up)
        )
    }
}
