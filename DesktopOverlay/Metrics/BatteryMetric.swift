import Foundation

/// Battery charge percentage via the public IOKit Power Sources API (spec §6).
/// Architecture-ready and fully working, but off by default to keep the overlay
/// small. Desktops without a battery report `.unavailable`.
final class BatteryMetric: SystemMetric {
    let id: MetricID = .battery

    func sample(interval: TimeInterval) -> MetricReading {
        guard let reading = SystemMetricsService.batteryPercentage() else { return .unavailable }
        return MetricReading(
            primary: .percent(reading.percent),
            components: ["charging": .text(reading.isCharging ? "Yes" : "No")],
            graphSample: (reading.percent / 100).clamped(to: 0...1)
        )
    }
}
