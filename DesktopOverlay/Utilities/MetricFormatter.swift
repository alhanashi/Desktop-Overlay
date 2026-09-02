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
        case .celsius(let v): return String(format: "%.0f°C", v)
        case .rpm(let v): return "\(Int(v.rounded())) rpm"
        case .text(let s): return s
        case .unavailable: return unavailable
        }
    }

    /// Spoken description for VoiceOver (spec §26).
    static func accessibilityText(for id: MetricID, reading: MetricReading?) -> String {
        let value = primaryText(for: id, reading: reading)
        let hint = stateHint(for: id, reading: reading).map { ", \($0)" } ?? ""
        return "\(id.displayName): \(value)\(hint)"
    }

    private static func component(_ reading: MetricReading, _ key: String) -> String {
        reading.components[key].map(string(for:)) ?? unavailable
    }

    /// One-line description of a metric, independent of any current reading.
    /// Used for the Metrics-menu tooltips and the Guide tab.
    static func shortDescription(for id: MetricID) -> String {
        switch id {
        case .cpu: return "Total processor usage (0–100%)."
        case .memory: return "Memory in use (0–100%), with memory-pressure state."
        case .disk: return "Disk read (↓) and write (↑) throughput."
        case .network: return "Network download (↓) and upload (↑) throughput."
        case .temperature: return "System thermal state (Nominal → Critical) — not degrees."
        case .cpuTemperature: return "CPU temperature in °C, read from the SMC (Intel Macs)."
        case .fan: return "Fastest fan speed in RPM; “high” means near this Mac’s maximum."
        case .battery: return "Battery charge level."
        case .gpu: return "Unavailable — no public macOS API reports system-wide GPU load."
        }
    }

    /// A one-word plain-language status shown next to the value (never colour
    /// alone — spec §26), so "is this normal?" is answerable at a glance.
    static func stateHint(for id: MetricID, reading: MetricReading?) -> String? {
        guard let reading else { return nil }
        switch id {
        case .fan:
            guard case .rpm(let rpm) = reading.primary else { return nil }
            if case .rpm(let low)? = reading.components["min"],
               case .rpm(let high)? = reading.components["max"], high > low {
                let fraction = (rpm - low) / (high - low)
                if fraction < 0.15 { return "idle" }
                if fraction < 0.55 { return "moderate" }
                return "high"
            }
            return rpm < 2500 ? "idle" : (rpm < 4000 ? "moderate" : "high")
        case .cpuTemperature:
            guard case .celsius(let c) = reading.primary else { return nil }
            if c < 65 { return "cool" }
            if c < 85 { return "warm" }
            return "hot"
        case .memory:
            if case .text(let pressure)? = reading.components["pressure"], pressure != "Normal" {
                return pressure.lowercased()
            }
            return nil
        default:
            return nil
        }
    }

    /// Full explanation shown as a hover tooltip on the row (spec §25 — usable
    /// without reading docs).
    static func tooltip(for id: MetricID, reading: MetricReading?) -> String {
        guard let reading else { return "\(id.displayName) — waiting for the first sample." }
        switch id {
        case .cpu:
            return "Total processor usage. User \(component(reading, "user")), "
                 + "system \(component(reading, "system")), idle \(component(reading, "idle"))."
        case .memory:
            return "Memory in use \(component(reading, "used")), available \(component(reading, "available")). "
                 + "Pressure: \(component(reading, "pressure"))."
        case .disk:
            return "Disk throughput — read \(component(reading, "read")), write \(component(reading, "write"))."
        case .network:
            return "Network throughput — download \(component(reading, "down")), upload \(component(reading, "up"))."
        case .temperature:
            return "System thermal state: Nominal (cool) → Fair → Serious → Critical (the system is throttling)."
        case .cpuTemperature:
            return "CPU temperature from the SMC sensor. Idle is typically 40–60 °C; "
                 + "sustained 90 °C+ means a heavy thermal load."
        case .fan:
            if case .rpm(let low)? = reading.components["min"],
               case .rpm(let high)? = reading.components["max"] {
                return "Fan speed. Normal range on this Mac is "
                     + "\(Int(low))–\(Int(high)) rpm — low when idle, near the top under load."
            }
            return "Fan speed in RPM — low when the Mac is cool, higher under load."
        case .battery:
            return "Battery charge. Charging: \(component(reading, "charging"))."
        case .gpu:
            return "GPU usage is not available through public macOS APIs."
        }
    }
}
