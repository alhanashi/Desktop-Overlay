import SwiftUI

/// A small circular speedometer dial (270° arc). Drawn with `Canvas` and no
/// animation, so it repaints only when a new sample arrives — same cost profile
/// as `SparklineView`.
struct GaugeView: View {
    /// Normalised 0...1.
    var value: Double

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let diameter = min(size.width, size.height)
            let lineWidth = max(2, diameter * 0.12)
            let radius = (diameter - lineWidth) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

            func path(sweep: Double) -> Path {
                var path = Path()
                let points = GaugeGeometry.arcPoints(center: center, radius: radius, sweep: sweep)
                path.move(to: points[0])
                points.dropFirst().forEach { path.addLine(to: $0) }
                return path
            }

            context.stroke(path(sweep: GaugeGeometry.totalSweepDegrees),
                           with: .color(.primary.opacity(0.18)), style: style)
            // At least a few degrees so an idle reading still shows a dot.
            context.stroke(path(sweep: max(3, GaugeGeometry.sweepDegrees(for: value))),
                           with: .color(.primary), style: style)
        }
        .accessibilityHidden(true)
    }
}
