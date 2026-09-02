import SwiftUI

/// Entry point. The app has no ordinary main window — only a floating overlay
/// panel and a menu bar item, both created by `AppDelegate`. The Settings
/// window is managed by `SettingsWindowController` (a real `NSWindow`), so this
/// scene is just an empty placeholder to satisfy the `App` requirement.
@main
struct DesktopOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
