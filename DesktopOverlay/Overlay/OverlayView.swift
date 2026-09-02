import SwiftUI

/// Root SwiftUI view hosted inside the overlay panel. Resizing is handled by a
/// separate AppKit `ResizeHandleView` added by `OverlayWindowController`.
struct OverlayRootView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var metrics: MetricsCoordinator

    var body: some View {
        OverlayContentView(settings: settings, metrics: metrics)
            .preferredColorScheme(settings.appearance.colorScheme)
            .ignoresSafeArea()
    }
}

/// The visible card: rounded, translucent, minimal (spec §4).
struct OverlayContentView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var metrics: MetricsCoordinator

    private var visibleMetrics: [MetricID] {
        MetricID.displayOrder.filter { settings.enabledMetrics.contains($0) }
    }

    private var rowSpacing: CGFloat { settings.sizeMode == .compact ? 3 : 7 }
    private var padding: CGFloat { settings.sizeMode == .compact ? 8 : 12 }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            if visibleMetrics.isEmpty {
                Text("No metrics selected")
                    .font(.system(size: settings.fontSize.labelPointSize))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleMetrics, id: \.self) { id in
                    OverlayRowView(
                        id: id,
                        reading: metrics.readings[id],
                        history: metrics.history[id] ?? [],
                        fontSize: settings.fontSize,
                        compact: settings.sizeMode == .compact
                    )
                }
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        // Explicit drag: the per-row `.help()` tooltips install tracking areas
        // that would otherwise defeat `isMovableByWindowBackground`.
        .gesture(WindowDragGesture())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("System metrics overlay")
    }
}
