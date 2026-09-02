import SwiftUI

/// Root SwiftUI view hosted inside the overlay panel.
struct OverlayRootView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var metrics: MetricsCoordinator

    /// Called by the resize grip. Translation is a delta in global points.
    var onResizeBegan: () -> Void
    var onResizeChanged: (CGSize) -> Void
    var onResizeEnded: () -> Void

    var body: some View {
        OverlayContentView(settings: settings, metrics: metrics)
            .overlay(alignment: .bottomTrailing) {
                ResizeGrip(onBegan: onResizeBegan,
                           onChanged: onResizeChanged,
                           onEnded: onResizeEnded)
                    .padding(3)
            }
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("System metrics overlay")
    }
}

/// Small drag handle in the bottom-right corner for resizing the panel
/// (borderless panels get no native edge-resize) (spec §3, §10).
private struct ResizeGrip: View {
    var onBegan: () -> Void
    var onChanged: (CGSize) -> Void
    var onEnded: () -> Void

    @State private var active = false

    var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .rotationEffect(.degrees(90))
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if !active { active = true; onBegan() }
                        onChanged(value.translation)
                    }
                    .onEnded { _ in
                        active = false
                        onEnded()
                    }
            )
            .help("Drag to resize")
            .accessibilityLabel("Resize overlay")
    }
}
