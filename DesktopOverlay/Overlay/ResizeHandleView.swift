import AppKit

/// Bottom-right resize grip, implemented in AppKit so it can opt out of
/// `isMovableByWindowBackground` (`mouseDownCanMoveWindow = false`). A SwiftUI
/// `DragGesture` here loses the event to AppKit's window-drag first.
///
/// Translation is reported in points with the same sign convention the window
/// controller expects: positive width = wider, positive height = taller, with
/// the top-left corner staying put.
final class ResizeHandleView: NSView {

    var onBegan: (() -> Void)?
    var onChanged: ((CGSize) -> Void)?
    var onEnded: (() -> Void)?

    private var anchor: NSPoint = .zero

    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.withAlphaComponent(0.65).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        let inset: CGFloat = 3
        for offset in stride(from: CGFloat(0), through: 6, by: 3) {
            path.move(to: CGPoint(x: bounds.maxX - inset - offset, y: bounds.minY + inset))
            path.line(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY + inset + offset))
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        anchor = NSEvent.mouseLocation
        onBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        // Screen coordinates are y-up: dragging down lowers y, which should make
        // the window taller, hence the negated dy.
        onChanged?(CGSize(width: now.x - anchor.x, height: anchor.y - now.y))
    }

    override func mouseUp(with event: NSEvent) {
        onEnded?()
    }
}
