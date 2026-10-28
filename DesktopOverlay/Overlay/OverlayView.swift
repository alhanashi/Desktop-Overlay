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

    private var isStrip: Bool { settings.displayStyle == .strip }

    @ViewBuilder private var layout: some View {
        if isStrip {
            // Laid out at its natural size, then scaled to fill the window, so
            // resizing the panel grows / shrinks the rings, icons and text.
            let natural = OverlayGeometry.stripSize(metricCount: visibleMetrics.count,
                                                    valuePointSize: settings.fontSize.valuePointSize,
                                                    compact: settings.sizeMode == .compact)
            GeometryReader { geo in
                let scale = max(0.1, min(geo.size.width / natural.width, geo.size.height / natural.height))
                StripView(metrics: visibleMetrics,
                          readings: metrics.readings,
                          fontSize: settings.fontSize,
                          compact: settings.sizeMode == .compact,
                          colour: settings.colourRings)
                    .frame(width: natural.width, height: natural.height)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        } else {
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
                            compact: settings.sizeMode == .compact,
                            style: settings.displayStyle,
                            colour: settings.colourRings
                        )
                    }
                }
            }
            .padding(padding)
        }
    }

    var body: some View {
        layout
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isStrip ? .center : .topLeading)
        .modifier(OverlayCardBackground(cornerRadius: settings.cornerRadius))
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("System metrics overlay")
    }
}
