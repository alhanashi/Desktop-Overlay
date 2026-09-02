import Foundation

/// Stable identifier for every metric the app knows about. New metrics (GPU,
/// Fan, Uptime, …) are added here plus a `SystemMetric` implementation — no
/// other change to the architecture is required (spec §17).
enum MetricID: String, CaseIterable, Codable, Sendable {
    case cpu
    case memory
    case disk
    case network
    case temperature
    case gpu
    case battery

    /// Short label shown in the overlay.
    var shortLabel: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "RAM"
        case .disk: return "Disk"
        case .network: return "Net"
        case .temperature: return "Temp"
        case .gpu: return "GPU"
        case .battery: return "Batt"
        }
    }

    /// Full name shown in menus and Settings.
    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .disk: return "Disk"
        case .network: return "Network"
        case .temperature: return "Temperature"
        case .gpu: return "GPU"
        case .battery: return "Battery"
        }
    }

    /// Fixed display order in the overlay.
    static let displayOrder: [MetricID] = [.cpu, .memory, .disk, .network, .temperature, .gpu, .battery]
}

/// A single displayable quantity. `.unavailable` is rendered as "—" (spec §27).
enum MetricValue: Equatable, Sendable {
    case percent(Double)          // 0...100
    case bytes(Double)            // absolute size, formatted with binary units
    case bytesPerSecond(Double)   // rate, formatted with binary units + "/s"
    case text(String)
    case unavailable
}

/// The result of sampling one metric.
struct MetricReading: Equatable, Sendable {
    /// The headline value shown in bold.
    var primary: MetricValue
    /// Extra breakdown values keyed by a caller-defined name
    /// (e.g. "user"/"system"/"idle" for CPU, "read"/"write" for Disk).
    var components: [String: MetricValue]
    /// Normalised 0...1 sample for the sparkline, or `nil` to draw no graph.
    var graphSample: Double?

    init(primary: MetricValue,
         components: [String: MetricValue] = [:],
         graphSample: Double? = nil) {
        self.primary = primary
        self.components = components
        self.graphSample = graphSample
    }

    static let unavailable = MetricReading(primary: .unavailable)
    /// Used for the very first tick of rate-based metrics, before a delta exists.
    static let pending = MetricReading(primary: .text("…"))
}
