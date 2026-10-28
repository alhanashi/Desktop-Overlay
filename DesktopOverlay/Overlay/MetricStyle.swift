import SwiftUI

/// UI-side styling for a metric, kept out of the Metrics model so that layer
/// stays free of SwiftUI.
extension MetricID {

    /// SF Symbol shown next to the metric name in the strip.
    var symbolName: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "arrow.up.arrow.down"
        case .temperature, .cpuTemperature: return "thermometer.medium"
        case .fan: return "fan"
        case .gpu: return "display"
        case .battery: return "battery.100"
        }
    }

    /// Identity colour for the ring (muted, readable on light and dark glass).
    /// Colour identifies the metric; state is always also written as a word.
    var ringColor: Color {
        switch self {
        case .cpu: return Color(red: 0.22, green: 0.54, blue: 0.87)          // blue
        case .memory: return Color(red: 0.11, green: 0.62, blue: 0.46)       // teal green
        case .disk: return Color(red: 0.50, green: 0.47, blue: 0.87)         // purple
        case .network: return Color(red: 0.94, green: 0.62, blue: 0.15)      // amber
        case .temperature, .cpuTemperature: return Color(red: 0.85, green: 0.35, blue: 0.19) // coral
        case .fan: return Color(red: 0.36, green: 0.79, blue: 0.65)          // mint
        case .gpu: return Color(red: 0.53, green: 0.53, blue: 0.50)          // grey
        case .battery: return Color(red: 0.39, green: 0.60, blue: 0.13)      // green
        }
    }
}
