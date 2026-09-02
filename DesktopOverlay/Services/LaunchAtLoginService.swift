import Foundation
import ServiceManagement

/// "Launch at Login" using the official API (spec §22): `SMAppService.mainApp`.
/// No shell scripts, no hand-installed LaunchAgents.
struct LaunchAtLoginService {

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Best-effort. A failure is logged and swallowed — it must never stop the
    /// rest of the app from working (spec §19).
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("[DesktopOverlay] Launch-at-login update failed: \(error.localizedDescription)")
        }
    }
}
