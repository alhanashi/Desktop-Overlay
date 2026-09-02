import Foundation

/// Memory used / available as a percentage, plus memory pressure (spec §5).
final class MemoryMetric: SystemMetric {
    let id: MetricID = .memory

    private let physical = ProcessInfo.processInfo.physicalMemory

    func sample(interval: TimeInterval) -> MetricReading {
        guard let raw = SystemMetricsService.memorySample() else { return .unavailable }

        let usage = MemoryCalculator.usage(
            sample: raw,
            pageSize: SystemMetricsService.pageSize,
            physical: physical
        )
        let pressure = SystemMetricsService.memoryPressure()

        return MetricReading(
            primary: .percent(usage.usedPercent),
            components: [
                "used": .bytes(Double(usage.usedBytes)),
                "available": .bytes(Double(usage.availableBytes)),
                "pressure": .text(pressure.label),
            ],
            graphSample: (usage.usedPercent / 100).clamped(to: 0...1)
        )
    }
}
