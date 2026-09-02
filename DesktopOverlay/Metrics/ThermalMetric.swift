import Foundation

/// System thermal state (spec §5, §21). There is **no reliable public API** for
/// CPU/GPU temperature in °C, so `ProcessInfo.thermalState` is surfaced instead:
/// Nominal / Fair / Serious / Critical.
final class ThermalMetric: SystemMetric {
    let id: MetricID = .temperature

    func sample(interval: TimeInterval) -> MetricReading {
        let label: String
        let level: Double
        switch SystemMetricsService.thermalState {
        case .nominal:  label = "Nominal";  level = 0.10
        case .fair:     label = "Fair";     level = 0.40
        case .serious:  label = "Serious";  level = 0.70
        case .critical: label = "Critical"; level = 1.00
        @unknown default: label = "Unknown"; level = 0
        }
        return MetricReading(
            primary: .text(label),
            components: [:],
            graphSample: level
        )
    }
}
