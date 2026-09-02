import AppKit
import SwiftUI

/// `NSHostingView` that also lets you drag the window from anywhere on the
/// content (spec §3, §10). `isMovableByWindowBackground` alone is fragile — any
/// child view with a tracking area (a tooltip, a hover effect) reports
/// `mouseDownCanMoveWindow == false` and silently disables it. Handling the
/// drag here with `performDrag(with:)` is immune to that.
///
/// The bottom-right `ResizeHandleView` is a sibling subview that receives its
/// own mouse events first, so resizing is unaffected.
final class DraggableHostingView<Content: View>: NSHostingView<Content> {

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDragged(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
