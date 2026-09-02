import Foundation

/// Total CPU usage with a user / system / idle breakdown (spec §5).
final class CPUMetric: SystemMetric {
    let id: MetricID = .cpu

    private var previousTicks: CPUTicks?

    init() {
        // Seed immediately so the first displayed sample is already a real delta.
        previousTicks = SystemMetricsService.cpuTicks()
    }

    func sample(interval: TimeInterval) -> MetricReading {
        guard let current = SystemMetricsService.cpuTicks() else { return .unavailable }
        defer { previousTicks = current }

        guard let previous = previousTicks else { return .pending }

        let usage = CPUCalculator.usage(from: previous, to: current)
        return MetricReading(
            primary: .percent(usage.total),
            components: [
                "user": .percent(usage.user),
                "system": .percent(usage.system),
                "idle": .percent(usage.idle),
            ],
            graphSample: (usage.total / 100).clamped(to: 0...1)
        )
    }
}
