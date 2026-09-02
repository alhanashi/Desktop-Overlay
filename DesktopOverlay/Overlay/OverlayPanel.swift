import AppKit

/// The floating overlay window (spec §9). A borderless, non-activating panel so
/// clicking it never steals focus from the app you're working in, it has no
/// title bar or chrome, and it can sit above normal windows on every Space.
final class OverlayPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Show on every Space and above full-screen apps, without pulling the
        // Dock or menu bar into view (spec §15).
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        minSize = OverlayGeometry.minSize
        maxSize = OverlayGeometry.maxSize
    }

    // Borderless panels don't become key by default; allow it so the SwiftUI
    // resize grip receives drag events. Still non-activating, so focus stays put.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
