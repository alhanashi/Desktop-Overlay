import AppKit
import Combine
import SwiftUI

/// Owns the `OverlayPanel`: builds it, hosts the SwiftUI content, applies live
/// settings (level, click-through, opacity, appearance), persists the frame, and
/// keeps the panel on-screen across display changes (spec §9, §10, §14).
@MainActor
final class OverlayWindowController {

    /// Set exactly once in `init` (and replaced by `rebuildPanel`); never nil after.
    private(set) var panel: OverlayPanel!

    private let settings: SettingsStore
    private let metrics: MetricsCoordinator
    private var cancellables = Set<AnyCancellable>()
    private var panelCancellables = Set<AnyCancellable>()
    private var persistWorkItem: DispatchWorkItem?
    private var resizeStartFrame: NSRect?
    private var panelIsAlwaysOnTop: Bool

    // Window size follows the display style (see `syncSizeToSettings`).
    private var lastStyle: DisplayStyle
    private var lastStripTarget: CGSize?
    private var sizeBeforeStrip: CGSize?

    private(set) var isVisible = false

    init(settings: SettingsStore, metrics: MetricsCoordinator) {
        self.settings = settings
        self.metrics = metrics

        panelIsAlwaysOnTop = settings.alwaysOnTop
        lastStyle = settings.displayStyle
        panel = makePanel(frame: Self.resolveInitialFrame(settings: settings),
                          alwaysOnTop: settings.alwaysOnTop)

        // A frame saved for another layout (or none) is re-fitted to the Strip's
        // natural size once; later launches keep whatever size the user chose.
        if settings.displayStyle == .strip {
            let natural = naturalStripSize()
            lastStripTarget = natural
            if settings.overlayFrameStyle != .strip {
                setSize(natural)
                persistFrameNow()
            }
        }

        observePanel()
        observeSettings()
        observeScreens()
    }

    // MARK: - Size follows the display style

    private func naturalStripSize() -> CGSize {
        let count = MetricID.displayOrder.filter { settings.enabledMetrics.contains($0) }.count
        return OverlayGeometry.stripSize(metricCount: count,
                                         valuePointSize: settings.fontSize.valuePointSize,
                                         compact: settings.sizeMode == .compact)
    }

    /// Resizes the panel keeping its top-left corner, nudged back on-screen.
    private func setSize(_ size: CGSize) {
        let current = panel.frame
        var proposed = NSRect(x: current.minX, y: current.maxY - size.height,
                              width: size.width, height: size.height)
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(current) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            if proposed.maxX > visible.maxX { proposed.origin.x = visible.maxX - proposed.width }
            if proposed.minX < visible.minX { proposed.origin.x = visible.minX }
            if proposed.maxY > visible.maxY { proposed.origin.y = visible.maxY - proposed.height }
            if proposed.minY < visible.minY { proposed.origin.y = visible.minY }
        }
        let clamped = OverlayGeometry.clampedFrame(
            proposed,
            into: NSScreen.screens.map { $0.visibleFrame },
            primary: Self.primaryVisibleFrame()
        )
        panel.setFrame(clamped, display: true, animate: false)
    }

    /// Re-fits the window when the style changes, and keeps the Strip's width in
    /// step with how many metrics / which font size and density it has. Only a
    /// change of the *natural* size triggers a resize, so a size the user drags
    /// to is left alone.
    private func syncSizeToSettings() {
        let style = settings.displayStyle
        if style != lastStyle {
            if style == .strip {
                sizeBeforeStrip = panel.frame.size
            } else if lastStyle == .strip {
                setSize(sizeBeforeStrip ?? OverlayGeometry.defaultSize)
            }
            lastStyle = style
            lastStripTarget = nil
        }
        if style == .strip {
            let target = naturalStripSize()
            if target != lastStripTarget {
                lastStripTarget = target
                setSize(target)
            }
        }
    }

    // MARK: - Building the panel

    /// Builds a fully configured panel: SwiftUI content, resize grip, and the
    /// current click-through / opacity / appearance settings.
    private func makePanel(frame: NSRect, alwaysOnTop: Bool) -> OverlayPanel {
        let panel = OverlayPanel(contentRect: frame, alwaysOnTop: alwaysOnTop)

        let hosting = DraggableHostingView(rootView: OverlayRootView(settings: settings, metrics: metrics))
        hosting.wantsLayer = true
        // The panel frame is authoritative — the SwiftUI content must fill it,
        // not resize it.
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.setContentSize(frame.size)

        // AppKit resize grip, pinned to the bottom-right corner.
        let handleSize: CGFloat = 16
        let handle = ResizeHandleView(frame: NSRect(
            x: hosting.bounds.maxX - handleSize, y: hosting.bounds.minY,
            width: handleSize, height: handleSize
        ))
        handle.autoresizingMask = [.minXMargin, .maxYMargin]
        handle.onBegan = { [weak self] in self?.resizeStartFrame = self?.panel.frame }
        handle.onChanged = { [weak self] translation in self?.applyResize(translation: translation) }
        handle.onEnded = { [weak self] in
            self?.resizeStartFrame = nil
            self?.schedulePersist()
        }
        hosting.addSubview(handle)

        panel.ignoresMouseEvents = settings.clickThrough
        panel.alphaValue = CGFloat(settings.opacity.clamped(to: 0.2...1.0))
        panel.appearance = settings.appearance.nsAppearance
        return panel
    }

    /// Replaces the panel with a fresh one built for the new "Always on Top"
    /// value, keeping its frame and visibility. Needed because a window's
    /// Space / full-screen membership is fixed when it is created.
    private func rebuildPanel(alwaysOnTop: Bool) {
        let old: OverlayPanel = panel
        let wasVisible = isVisible
        panel = makePanel(frame: old.frame, alwaysOnTop: alwaysOnTop)
        panelIsAlwaysOnTop = alwaysOnTop
        observePanel()
        if wasVisible { panel.orderFrontRegardless() }
        old.orderOut(nil)
        old.contentView = nil
        old.close()
    }

    // MARK: - Show / hide

    func showOverlay() {
        panel.orderFrontRegardless()
        isVisible = true
        settings.overlayVisible = true
        metrics.setPaused(false)
    }

    func hideOverlay() {
        panel.orderOut(nil)
        isVisible = false
        settings.overlayVisible = false
        metrics.setPaused(true)
    }

    func toggleOverlay() {
        isVisible ? hideOverlay() : showOverlay()
    }

    /// Re-centre the overlay on the primary screen (menu: "Reset Position").
    func resetPosition() {
        let primary = Self.primaryVisibleFrame()
        panel.setFrame(OverlayGeometry.defaultFrame(on: primary), display: true, animate: false)
        persistFrameNow()
    }

    // MARK: - Live settings

    private func observeSettings() {
        // NOTE: `@Published` fires its publisher in `willSet`, so the closure
        // must use the *emitted* value — reading `settings.x` here would return
        // the previous value and make every apply lag one change behind (which
        // left click-through stuck on after an on→off toggle).
        settings.$alwaysOnTop
            .sink { [weak self] value in
                guard let self, value != self.panelIsAlwaysOnTop else { return }
                self.rebuildPanel(alwaysOnTop: value)
            }
            .store(in: &cancellables)
        // After the change has settled (objectWillChange fires first), re-fit the
        // window to the display style / metric set / font size / density.
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncSizeToSettings() }
            .store(in: &cancellables)
        settings.$clickThrough
            .sink { [weak self] value in self?.panel.ignoresMouseEvents = value }.store(in: &cancellables)
        settings.$opacity
            .sink { [weak self] value in self?.panel.alphaValue = CGFloat(value.clamped(to: 0.2...1.0)) }
            .store(in: &cancellables)
        settings.$appearance
            .sink { [weak self] value in self?.panel.appearance = value.nsAppearance }.store(in: &cancellables)
    }

    // MARK: - Resize (from the SwiftUI grip)

    private func applyResize(translation: CGSize) {
        guard let start = resizeStartFrame else { return }
        var width = (start.width + translation.width)
            .clamped(to: OverlayGeometry.minSize.width...OverlayGeometry.maxSize.width)
        var height = (start.height + translation.height)
            .clamped(to: OverlayGeometry.minSize.height...OverlayGeometry.maxSize.height)
        if settings.displayStyle == .strip {
            // The Strip scales with the window, so keep its proportions.
            let natural = naturalStripSize()
            let aspect = natural.width / natural.height
            let minW = max(OverlayGeometry.minSize.width, OverlayGeometry.minSize.height * aspect)
            let maxW = min(OverlayGeometry.maxSize.width, OverlayGeometry.maxSize.height * aspect)
            width = width.clamped(to: minW...max(minW, maxW))
            height = width / aspect
        }
        // Keep the top-left corner anchored while the bottom-right follows.
        let topLeftY = start.maxY
        panel.setFrame(
            NSRect(x: start.minX, y: topLeftY - height, width: width, height: height),
            display: true,
            animate: false
        )
    }

    // MARK: - Frame persistence & multi-display

    /// Window notifications are tied to one panel instance, so they are
    /// re-subscribed whenever the panel is rebuilt.
    private func observePanel() {
        panelCancellables.removeAll()
        let center = NotificationCenter.default
        center.publisher(for: NSWindow.didMoveNotification, object: panel)
            .sink { [weak self] _ in self?.schedulePersist() }
            .store(in: &panelCancellables)
        center.publisher(for: NSWindow.didResizeNotification, object: panel)
            .sink { [weak self] _ in self?.schedulePersist() }
            .store(in: &panelCancellables)
    }

    private func observeScreens() {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .sink { [weak self] _ in self?.keepOnScreen() }
            .store(in: &cancellables)
    }

    private func schedulePersist() {
        persistWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persistFrameNow() }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func persistFrameNow() {
        settings.overlayFrame = panel.frame
        settings.overlayFrameStyle = settings.displayStyle
    }

    private func keepOnScreen() {
        let screens = NSScreen.screens.map { $0.visibleFrame }
        let clamped = OverlayGeometry.clampedFrame(
            panel.frame,
            into: screens,
            primary: Self.primaryVisibleFrame()
        )
        if clamped != panel.frame {
            panel.setFrame(clamped, display: true, animate: false)
            persistFrameNow()
        }
    }

    // MARK: - Initial frame

    private static func primaryVisibleFrame() -> CGRect {
        (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private static func resolveInitialFrame(settings: SettingsStore) -> NSRect {
        let screens = NSScreen.screens.map { $0.visibleFrame }
        let primary = primaryVisibleFrame()
        if let saved = settings.overlayFrame {
            return OverlayGeometry.clampedFrame(saved, into: screens, primary: primary)
        }
        return OverlayGeometry.defaultFrame(on: primary)
    }
}
