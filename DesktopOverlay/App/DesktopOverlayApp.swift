import SwiftUI

/// Entry point. The app has no ordinary main window — only a floating overlay
/// panel and a menu bar item, both created by `AppDelegate`. The single SwiftUI
/// scene is the standard Settings window (opened with ⌘, or from the menu).
@main
struct DesktopOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
        }
    }
}
