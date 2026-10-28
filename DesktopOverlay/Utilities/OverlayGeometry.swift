import CoreGraphics
import Foundation

/// Pure geometry helpers for the overlay window. Kept free of AppKit so they
/// can be unit-tested with plain `CGRect`s (spec §14, §28).
enum OverlayGeometry {

    static let defaultSize = CGSize(width: 220, height: 140)
    static let minSize = CGSize(width: 150, height: 70)
    static let maxSize = CGSize(width: 1100, height: 560)

    /// The natural window size for the `strip` display style: one column per
    /// metric in a single row, sized from the ring diameter. Clamped to the
    /// window's min/max so it can never exceed what the panel allows.
    static func stripSize(metricCount: Int, valuePointSize: CGFloat, compact: Bool) -> CGSize {
        let columns = CGFloat(max(1, metricCount))
        let ring = StripLayout.ringSize(valuePointSize: valuePointSize, compact: compact)
        let cell = StripLayout.cellWidth(valuePointSize: valuePointSize, compact: compact)
        let width = columns * cell + (columns - 1) * StripLayout.cellSpacing + 2 * StripLayout.padding
        let textBlock: CGFloat = compact ? 24 : 78      // name row, plus detail and hint lines
        let height = ring + textBlock + 2 * StripLayout.padding
        return CGSize(width: width.clamped(to: minSize.width...maxSize.width),
                      height: height.clamped(to: minSize.height...maxSize.height))
    }

    /// A frame counts as visible if it overlaps some screen by at least
    /// `minVisible` points on both axes.
    static func isFrameVisible(_ frame: CGRect,
                               in screenFrames: [CGRect],
                               minVisible: CGFloat = 40) -> Bool {
        for screen in screenFrames {
            let overlap = screen.intersection(frame)
            if overlap.width >= minVisible && overlap.height >= minVisible {
                return true
            }
        }
        return false
    }

    /// If `frame` is at least partly on some screen it is returned unchanged.
    /// Otherwise it is resized into bounds and re-centred on `primary`
    /// (spec §14: "if the position becomes invalid, place it inside the
    /// primary screen").
    static func clampedFrame(_ frame: CGRect,
                             into screenFrames: [CGRect],
                             primary: CGRect) -> CGRect {
        if isFrameVisible(frame, in: screenFrames) {
            return frame
        }
        let size = CGSize(
            width: frame.width.clamped(to: minSize.width...maxSize.width),
            height: frame.height.clamped(to: minSize.height...maxSize.height)
        )
        let origin = CGPoint(
            x: primary.midX - size.width / 2,
            y: primary.midY - size.height / 2
        )
        return CGRect(origin: origin, size: size).integral
    }

    /// A default-sized frame centred on `primary`.
    static func defaultFrame(on primary: CGRect) -> CGRect {
        CGRect(
            x: primary.midX - defaultSize.width / 2,
            y: primary.midY - defaultSize.height / 2,
            width: defaultSize.width,
            height: defaultSize.height
        ).integral
    }
}
