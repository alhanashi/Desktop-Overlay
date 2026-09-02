import Foundation

/// Formats `MetricValue`s for the compact overlay display.
enum MetricFormatter {

    static let unavailable = "—"

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// Binary units, adaptive precision. e.g. `4.2 MB/s`, `120 MB/s`, `0 KB/s`.
    static func rate(_ bytesPerSecond: Double) -> String {
        byteString(bytesPerSecond, suffix: "/s")
    }

    static func size(_ bytes: Double) -> String {
        byteString(bytes, suffix: "")
    }

    private static func byteString(_ bytes: Double, suffix: String) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(bytes, 0)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        let fractionDigits = (index == 0 || value >= 100) ? 0 : 1
        return String(format: "%.\(fractionDigits)f %@%@", value, units[index], suffix)
    }

    /// Headline string for a metric row.
    static func primaryText(for id: MetricID, reading: MetricReading?) -> String {
        guard let reading else { return unavailable }
        switch id {
        case .disk, .network:
            let downKey = id == .disk ? "read" : "down"
            let upKey = id == .disk ? "write" : "up"
            guard case .bytesPerSecond(let down)? = reading.components[downKey],
                  case .bytesPerSecond(let up)? = reading.components[upKey] else {
                return string(for: reading.primary)
            }
            return "↓ \(rate(down))  ↑ \(rate(up))"
        default:
            return string(for: reading.primary)
        }
    }

    static func string(for value: MetricValue) -> String {
        switch value {
        case .percent(let v): return percent(v)
        case .bytes(let v): return size(v)
        case .bytesPerSecond(let v): return rate(v)
        case .text(let s): return s
        case .unavailable: return unavailable
        }
    }

    /// Spoken description for VoiceOver (spec §26).
    static func accessibilityText(for id: MetricID, reading: MetricReading?) -> String {
        let value = primaryText(for: id, reading: reading)
        return "\(id.displayName): \(value)"
    }
}
