import AppKit
import SwiftUI

/// Hosts `SettingsView` in a plain `NSWindow` we own. The SwiftUI `Settings`
/// scene plus the private `showSettingsWindow:` selector is unreliable to
/// trigger from an accessory (menu-bar) app; a window we create and order
/// front ourselves always works.
@MainActor
final class SettingsWindowController {

    private let settings: SettingsStore
    private var window: NSWindow?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let controller = NSHostingController(
                rootView: SettingsView().environmentObject(settings)
            )
            let window = NSWindow(contentViewController: controller)
            window.title = "Desktop Overlay Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.identifier = NSUserInterfaceItemIdentifier("DesktopOverlaySettings")
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
