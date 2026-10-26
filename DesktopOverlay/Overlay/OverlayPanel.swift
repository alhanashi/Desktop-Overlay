import AppKit

/// The floating overlay window (spec §9). A borderless, non-activating panel so
/// clicking it never steals focus from the app you're working in, it has no
/// title bar or chrome, and it can sit above normal windows on every Space.
final class OverlayPanel: NSPanel {

    /// `alwaysOnTop` is fixed for the life of the window: Space / full-screen
    /// membership is decided when a window is created (measured — changing
    /// `collectionBehavior` later has no effect), so the controller builds a new
    /// panel whenever the setting changes.
    init(contentRect: NSRect, alwaysOnTop: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        // `isFloatingPanel` tracks the setting too: while it is true the panel
        // stays above other windows regardless of `level`.
        isFloatingPanel = alwaysOnTop
        level = alwaysOnTop ? .floating : .normal
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        collectionBehavior = Self.collectionBehavior(alwaysOnTop: alwaysOnTop)

        minSize = OverlayGeometry.minSize
        maxSize = OverlayGeometry.maxSize
    }

    /// Which Spaces the panel appears in. Both modes follow you across normal
    /// Spaces. With "Always on Top" on, `fullScreenAuxiliary` also lets it sit
    /// over another app's full-screen Space without pulling the Dock or menu bar
    /// into view. With it off, `fullScreenNone` is used instead: measured on
    /// macOS 26, `canJoinAllSpaces` alone (with or without `stationary`) still
    /// shows the window over full-screen apps, while `canJoinAllSpaces` +
    /// `fullScreenNone` hides it there like an ordinary window.
    static func collectionBehavior(alwaysOnTop: Bool) -> NSWindow.CollectionBehavior {
        alwaysOnTop
            ? [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            : [.canJoinAllSpaces, .fullScreenNone, .ignoresCycle]
    }

    // Borderless panels don't become key by default; allow it so the SwiftUI
    // resize grip receives drag events. Still non-activating, so focus stays put.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
