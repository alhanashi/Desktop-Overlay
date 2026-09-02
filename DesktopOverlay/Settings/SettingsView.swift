import SwiftUI

/// Native Settings window (spec §12). Four tabs; every control is bound straight
/// to `SettingsStore`, so changes apply to the overlay immediately.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            MetricsSettingsTab()
                .tabItem { Label("Metrics", systemImage: "chart.bar.xaxis") }
            UpdateSettingsTab()
                .tabItem { Label("Update", systemImage: "clock.arrow.circlepath") }
        }
        .frame(width: 440, height: 340)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            Toggle("Show overlay automatically on launch", isOn: $settings.startOverlayAutomatically)
            Toggle("Always on top", isOn: $settings.alwaysOnTop)
            Toggle("Click through (overlay ignores the mouse)", isOn: $settings.clickThrough)
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Form {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            LabeledContent("Opacity") {
                Slider(value: $settings.opacity, in: 0.3...1.0, step: 0.05)
                Text("\(Int(settings.opacity * 100))%").monospacedDigit().frame(width: 42, alignment: .trailing)
            }

            LabeledContent("Corner radius") {
                Slider(value: $settings.cornerRadius, in: 0...20, step: 1)
                Text("\(Int(settings.cornerRadius))").monospacedDigit().frame(width: 42, alignment: .trailing)
            }

            Picker("Font size", selection: $settings.fontSize) {
                ForEach(FontSizeMode.allCases) { Text($0.label).tag($0) }
            }
            Picker("Overlay size", selection: $settings.sizeMode) {
                ForEach(OverlaySizeMode.allCases) { Text($0.label).tag($0) }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Metrics

private struct MetricsSettingsTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var smcAvailable = SMCService.shared.isAvailable

    private let standard: [MetricID] = [.cpu, .memory, .disk, .network, .temperature, .battery]

    var body: some View {
        Form {
            Section {
                ForEach(standard, id: \.self) { id in
                    Toggle(id.displayName, isOn: binding(for: id))
                }
            }

            Section {
                Toggle(MetricID.cpuTemperature.displayName, isOn: binding(for: .cpuTemperature))
                    .disabled(!smcAvailable)
                Toggle(MetricID.fan.displayName, isOn: binding(for: .fan))
                    .disabled(!smcAvailable)
            } header: {
                Text("Sensors (SMC)")
            } footer: {
                Text(smcAvailable
                     ? "These read undocumented SMC keys. They may stop working after a macOS update and need no special permissions."
                     : "SMC sensors are unavailable on this Mac (typically Apple Silicon or a fanless model).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("GPU", isOn: .constant(false))
                    .disabled(true)
                    .help("No public macOS API exposes system-wide GPU usage.")
            } footer: {
                Text("GPU usage is not available through public macOS APIs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for id: MetricID) -> Binding<Bool> {
        Binding(
            get: { settings.enabledMetrics.contains(id) },
            set: { settings.setMetric(id, enabled: $0) }
        )
    }
}

// MARK: - Update

private struct UpdateSettingsTab: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Update interval", selection: $settings.updateInterval) {
                    ForEach(UpdateInterval.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("Under system thermal pressure the interval is automatically stretched to reduce energy use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
