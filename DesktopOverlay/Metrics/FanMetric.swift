import Foundation

/// Fan speed (highest fan) in RPM via the SMC (spec §6, opt-in). Same
/// undocumented-key caveats as `SMCTemperatureMetric`. Fanless Macs and Apple
/// Silicon report `.unavailable`.
final class FanMetric: SystemMetric {
    let id: MetricID = .fan

    private var graphMax = DecayingMax(decay: 0.97, floor: 3_000)

    func sample(interval: TimeInterval) -> MetricReading {
        guard let rpm = SMCService.shared.fanRPM() else { return .unavailable }
        return MetricReading(
            primary: .rpm(rpm),
            components: [:],
            graphSample: graphMax.normalise(rpm)
        )
    }
}
