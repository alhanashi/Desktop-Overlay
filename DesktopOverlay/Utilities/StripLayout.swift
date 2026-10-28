import CoreGraphics

/// Shared sizing constants for the `strip` display style, in one place so the
/// SwiftUI view and the window's natural-size calculation can never disagree.
enum StripLayout {

    static let padding: CGFloat = 12
    static let cellSpacing: CGFloat = 4

    /// Ring diameter, scaled with the Font size setting (Medium = 14 pt ⇒ ≈76 pt).
    static func ringSize(valuePointSize: CGFloat, compact: Bool) -> CGFloat {
        (valuePointSize * (compact ? 4.0 : 5.4)).rounded()
    }

    /// Column width: the ring plus room for the detail text underneath.
    static func cellWidth(valuePointSize: CGFloat, compact: Bool) -> CGFloat {
        ringSize(valuePointSize: valuePointSize, compact: compact) + (compact ? 16 : 28)
    }
}
