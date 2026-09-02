import Foundation

/// CPU temperature in °C via the SMC (spec §6, opt-in). Reads an undocumented
/// SMC key through `SMCService`; see that file for the caveats. Reports
/// `.unavailable` on Apple Silicon or if no key is readable.
final class SMCTemperatureMetric: SystemMetric {
    let id: MetricID = .cpuTemperature

    func sample(interval: TimeInterval) -> MetricReading {
        guard let celsius = SMCService.shared.cpuTemperature() else { return .unavailable }
        return MetricReading(
            primary: .celsius(celsius),
            components: [:],
            graphSample: (celsius / 100).clamped(to: 0...1)
        )
    }
}
