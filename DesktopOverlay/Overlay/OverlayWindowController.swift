import AppKit
import Combine
import SwiftUI

/// Owns the `OverlayPanel`: builds it, hosts the SwiftUI content, applies live
/// settings (level, click-through, opacity, appearance), persists the frame, and
/// keeps the panel on-screen across display changes (spec §9, §10, §14).
@MainActor
final class OverlayWindowController {

    let panel: OverlayPanel

    private let settings: SettingsStore
    private let metrics: MetricsCoordinator
    private var cancellables = Set<AnyCancellable>()
    private var persistWorkItem: DispatchWorkItem?
    private var resizeStartFrame: NSRect?

    private(set) var isVisible = false

    init(settings: SettingsStore, metrics: MetricsCoordinator) {
        self.settings = settings
        self.metrics = metrics

        let initialFrame = Self.resolveInitialFrame(settings: settings)
        panel = OverlayPanel(contentRect: initialFrame)

        let hosting = DraggableHostingView(rootView: OverlayRootView(settings: settings, metrics: metrics))
        hosting.wantsLayer = true
        // The panel frame is authoritative — the SwiftUI content must fill it,
        // not resize it.
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.setContentSize(initialFrame.size)

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

        applyLevel()
        applyClickThrough()
        applyOpacity()
        applyAppearance()
        observeSettings()
        observeWindowAndScreen()
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
        settings.$alwaysOnTop
            .sink { [weak self] _ in self?.applyLevel() }.store(in: &cancellables)
        settings.$clickThrough
            .sink { [weak self] _ in self?.applyClickThrough() }.store(in: &cancellables)
        settings.$opacity
            .sink { [weak self] _ in self?.applyOpacity() }.store(in: &cancellables)
        settings.$appearance
            .sink { [weak self] _ in self?.applyAppearance() }.store(in: &cancellables)
    }

    private func applyLevel() {
        panel.level = settings.alwaysOnTop ? .floating : .normal
    }

    private func applyClickThrough() {
        panel.ignoresMouseEvents = settings.clickThrough
    }

    private func applyOpacity() {
        panel.alphaValue = CGFloat(settings.opacity.clamped(to: 0.2...1.0))
    }

    private func applyAppearance() {
        panel.appearance = settings.appearance.nsAppearance
    }

    // MARK: - Resize (from the SwiftUI grip)

    private func applyResize(translation: CGSize) {
        guard let start = resizeStartFrame else { return }
        let width = (start.width + translation.width)
            .clamped(to: OverlayGeometry.minSize.width...OverlayGeometry.maxSize.width)
        let height = (start.height + translation.height)
            .clamped(to: OverlayGeometry.minSize.height...OverlayGeometry.maxSize.height)
        // Keep the top-left corner anchored while the bottom-right follows.
        let topLeftY = start.maxY
        panel.setFrame(
            NSRect(x: start.minX, y: topLeftY - height, width: width, height: height),
            display: true,
            animate: false
        )
    }

    // MARK: - Frame persistence & multi-display

    private func observeWindowAndScreen() {
        let center = NotificationCenter.default
        center.publisher(for: NSWindow.didMoveNotification, object: panel)
            .sink { [weak self] _ in self?.schedulePersist() }
            .store(in: &cancellables)
        center.publisher(for: NSWindow.didResizeNotification, object: panel)
            .sink { [weak self] _ in self?.schedulePersist() }
            .store(in: &cancellables)
        center.publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
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
