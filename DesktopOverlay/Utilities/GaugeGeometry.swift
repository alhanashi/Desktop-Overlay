import CoreGraphics
import Foundation

/// Pure geometry for the circular speedometer dial: a 270° arc that starts at
/// the bottom-left (135° clockwise from 3 o'clock, screen coordinates, y down)
/// and sweeps over the top to the bottom-right. Kept free of SwiftUI so it can
/// be unit-tested.
enum GaugeGeometry {

    static let startDegrees: Double = 135
    static let totalSweepDegrees: Double = 270

    /// Clamps to 0...1; NaN and infinities become 0.
    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    /// Arc length in degrees for a normalised value.
    static func sweepDegrees(for value: Double) -> Double {
        clamped(value) * totalSweepDegrees
    }

    /// Points along the arc from `startDegrees` over `sweep` degrees. Angles
    /// grow clockwise on screen because the y axis points down. Always returns
    /// at least two points so a near-zero arc still draws a dot.
    static func arcPoints(center: CGPoint,
                          radius: CGFloat,
                          sweep: Double,
                          maxSegmentDegrees: Double = 10) -> [CGPoint] {
        let segments = max(1, Int((sweep / maxSegmentDegrees).rounded(.up)))
        return (0...segments).map { index in
            let degrees = startDegrees + sweep * Double(index) / Double(segments)
            let radians = degrees * .pi / 180
            return CGPoint(x: center.x + radius * CGFloat(cos(radians)),
                           y: center.y + radius * CGFloat(sin(radians)))
        }
    }
}
