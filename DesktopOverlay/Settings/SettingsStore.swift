import AppKit
import Combine
import SwiftUI

// MARK: - Value types

enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum UpdateInterval: Int, CaseIterable, Identifiable, Sendable {
    case one = 1, two = 2, five = 5
    var id: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue) }
    var label: String { rawValue == 1 ? "1 second" : "\(rawValue) seconds" }
}

enum OverlaySizeMode: String, CaseIterable, Identifiable, Sendable {
    case compact, normal
    var id: String { rawValue }
    var label: String { self == .compact ? "Compact" : "Normal" }
}

enum FontSizeMode: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var labelPointSize: CGFloat {
        switch self { case .small: return 9; case .medium: return 10; case .large: return 12 }
    }
    var valuePointSize: CGFloat {
        switch self { case .small: return 12; case .medium: return 14; case .large: return 17 }
    }
}

// MARK: - Store

/// The single source of truth for every persisted setting (spec §13). Backed by
/// `UserDefaults`; no database. Injected everywhere that needs configuration and
/// observed via Combine so changes apply live.
@MainActor
final class SettingsStore: ObservableObject {

    private enum Key {
        static let overlayFrame = "overlay.frame"
        static let overlayVisible = "overlay.visible"
        static let opacity = "appearance.opacity"
        static let cornerRadius = "appearance.cornerRadius"
        static let fontSize = "appearance.fontSize"
        static let sizeMode = "appearance.sizeMode"
        static let appearance = "appearance.mode"
        static let enabledMetrics = "metrics.enabled"
        static let updateInterval = "update.interval"
        static let alwaysOnTop = "window.alwaysOnTop"
        static let clickThrough = "window.clickThrough"
        static let launchAtLogin = "general.launchAtLogin"
        static let startOverlayAutomatically = "general.startOverlayAutomatically"
    }

    private let defaults: UserDefaults

    @Published var opacity: Double { didSet { defaults.set(opacity, forKey: Key.opacity) } }
    @Published var cornerRadius: Double { didSet { defaults.set(cornerRadius, forKey: Key.cornerRadius) } }
    @Published var fontSize: FontSizeMode { didSet { defaults.set(fontSize.rawValue, forKey: Key.fontSize) } }
    @Published var sizeMode: OverlaySizeMode { didSet { defaults.set(sizeMode.rawValue, forKey: Key.sizeMode) } }
    @Published var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }
    @Published var enabledMetrics: Set<MetricID> {
        didSet { defaults.set(enabledMetrics.map(\.rawValue).sorted(), forKey: Key.enabledMetrics) }
    }
    @Published var updateInterval: UpdateInterval { didSet { defaults.set(updateInterval.rawValue, forKey: Key.updateInterval) } }
    @Published var alwaysOnTop: Bool { didSet { defaults.set(alwaysOnTop, forKey: Key.alwaysOnTop) } }
    @Published var clickThrough: Bool { didSet { defaults.set(clickThrough, forKey: Key.clickThrough) } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }
    @Published var startOverlayAutomatically: Bool { didSet { defaults.set(startOverlayAutomatically, forKey: Key.startOverlayAutomatically) } }
    @Published var overlayVisible: Bool { didSet { defaults.set(overlayVisible, forKey: Key.overlayVisible) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.opacity: 0.85,
            Key.cornerRadius: 12.0,
            Key.fontSize: FontSizeMode.medium.rawValue,
            Key.sizeMode: OverlaySizeMode.normal.rawValue,
            Key.appearance: AppearanceMode.system.rawValue,
            Key.enabledMetrics: [MetricID.cpu, .memory, .disk, .network].map(\.rawValue),
            Key.updateInterval: UpdateInterval.one.rawValue,
            Key.alwaysOnTop: true,
            Key.clickThrough: false,
            Key.launchAtLogin: false,
            Key.startOverlayAutomatically: true,
            Key.overlayVisible: true,
        ])

        opacity = defaults.double(forKey: Key.opacity)
        cornerRadius = defaults.double(forKey: Key.cornerRadius)
        fontSize = FontSizeMode(rawValue: defaults.string(forKey: Key.fontSize) ?? "") ?? .medium
        sizeMode = OverlaySizeMode(rawValue: defaults.string(forKey: Key.sizeMode) ?? "") ?? .normal
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        enabledMetrics = Set((defaults.stringArray(forKey: Key.enabledMetrics) ?? [])
            .compactMap(MetricID.init(rawValue:)))
        updateInterval = UpdateInterval(rawValue: defaults.integer(forKey: Key.updateInterval)) ?? .one
        alwaysOnTop = defaults.bool(forKey: Key.alwaysOnTop)
        clickThrough = defaults.bool(forKey: Key.clickThrough)
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        startOverlayAutomatically = defaults.bool(forKey: Key.startOverlayAutomatically)
        overlayVisible = defaults.bool(forKey: Key.overlayVisible)
    }

    // MARK: - Overlay frame (stored as a string, kept off the @Published graph)

    var overlayFrame: CGRect? {
        get {
            guard let encoded = defaults.string(forKey: Key.overlayFrame) else { return nil }
            let rect = NSRectFromString(encoded)
            return (rect.width > 0 && rect.height > 0) ? rect : nil
        }
        set {
            if let rect = newValue {
                defaults.set(NSStringFromRect(rect), forKey: Key.overlayFrame)
            } else {
                defaults.removeObject(forKey: Key.overlayFrame)
            }
        }
    }

    // MARK: - Helpers

    func isMetricEnabled(_ id: MetricID) -> Bool { enabledMetrics.contains(id) }

    func setMetric(_ id: MetricID, enabled: Bool) {
        if enabled { enabledMetrics.insert(id) } else { enabledMetrics.remove(id) }
    }

    /// Force any pending defaults to disk (called on quit — spec §23).
    func flush() {
        defaults.synchronize()
    }
}
