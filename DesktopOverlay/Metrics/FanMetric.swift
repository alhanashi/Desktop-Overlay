import Foundation

/// Fan speed (highest fan) in RPM via the SMC (spec §6, opt-in). Same
/// undocumented-key caveats as `SMCTemperatureMetric`. Fanless Macs and Apple
/// Silicon report `.unavailable`.
///
/// The sparkline and the "idle / moderate / high" hint are scaled against the
/// fan's real `F0Mn`…`F0Mx` range so the reading is self-explanatory.
final class FanMetric: SystemMetric {
    let id: MetricID = .fan

    private var range: (min: Double, max: Double)?
    private var resolvedRange = false

    func sample(interval: TimeInterval) -> MetricReading {
        guard let rpm = SMCService.shared.fanRPM() else { return .unavailable }

        if !resolvedRange {
            resolvedRange = true
            range = SMCService.shared.fanRange()
        }

        var components: [String: MetricValue] = [:]
        var graph = (rpm / 6_000).clamped(to: 0...1)

        if let range {
            components["min"] = .rpm(range.min)
            components["max"] = .rpm(range.max)
            let span = range.max - range.min
            if span > 0 { graph = ((rpm - range.min) / span).clamped(to: 0...1) }
        }

        return MetricReading(primary: .rpm(rpm), components: components, graphSample: graph)
    }
}
