import AppKit
import Combine

/// Owns the application lifecycle (spec §23):
///
///   Launch → init Settings → init Metrics → create Overlay →
///   create Menu Bar → start Metric updates
///
///   Quit → stop updates → save settings → close overlay → exit
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Single source of truth for all persisted configuration.
    let settings = SettingsStore()

    private lazy var metrics = MetricsCoordinator(settings: settings)
    private let launchService = LaunchAtLoginService()

    private var overlayController: OverlayWindowController?
    private var menuBarController: MenuBarController?
    private lazy var settingsWindow = SettingsWindowController(settings: settings)
    private var cancellables = Set<AnyCancellable>()

    /// True when the process is running the XCTest bundle. In that case we skip
    /// all UI/side-effectful startup so unit tests stay hermetic.
    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }

        NSApp.setActivationPolicy(.accessory)

        // Reconcile the persisted "launch at login" flag with the real state.
        settings.launchAtLogin = launchService.isEnabled

        let overlay = OverlayWindowController(settings: settings, metrics: metrics)
        overlayController = overlay

        let menuBar = MenuBarController(settings: settings,
                                       metrics: metrics,
                                       overlay: overlay,
                                       launchService: launchService,
                                       openSettings: { [weak self] in self?.settingsWindow.show() })
        menuBarController = menuBar

        // Apply the "launch at login" toggle whenever it changes in Settings.
        settings.$launchAtLogin
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.launchService.setEnabled(enabled)
            }
            .store(in: &cancellables)

        if settings.overlayVisible {
            overlay.showOverlay()
        } else {
            overlay.hideOverlay()
        }

        metrics.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        metrics.stop()
        overlayController?.persistFrameNow()
        settings.flush()
    }

    /// Accessory apps have no Dock icon; there is nothing to "reopen".
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
