import SwiftUI

/// A tiny line graph of the last N samples (spec §18). Drawn with `Canvas`,
/// no animations, and re-rendered only when `samples` actually changes — it
/// costs effectively nothing when the values are steady.
struct SparklineView: View {
    /// Normalised 0...1 values, oldest → newest.
    var samples: [Double]

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            guard samples.count >= 2 else { return }

            let stepX = size.width / CGFloat(samples.count - 1)
            func point(_ index: Int) -> CGPoint {
                let clamped = samples[index].clamped(to: 0...1)
                return CGPoint(x: CGFloat(index) * stepX,
                               y: size.height * (1 - CGFloat(clamped)))
            }

            var line = Path()
            line.move(to: point(0))
            for index in 1..<samples.count { line.addLine(to: point(index)) }

            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()

            context.fill(fill, with: .color(.primary.opacity(0.12)))
            context.stroke(line, with: .color(.primary.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
