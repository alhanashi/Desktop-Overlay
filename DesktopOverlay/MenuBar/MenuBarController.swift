import AppKit
import Combine

/// The menu bar item and its menu (spec §11). The menu is rebuilt every time it
/// opens so checkmarks always reflect the current `SettingsStore`.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let settings: SettingsStore
    private let metrics: MetricsCoordinator
    private weak var overlay: OverlayWindowController?
    private let launchService: LaunchAtLoginService
    private var cancellables = Set<AnyCancellable>()

    private let menuMetrics: [MetricID] = [.cpu, .memory, .disk, .network, .temperature]

    init(settings: SettingsStore,
         metrics: MetricsCoordinator,
         overlay: OverlayWindowController,
         launchService: LaunchAtLoginService) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.settings = settings
        self.metrics = metrics
        self.overlay = overlay
        self.launchService = launchService
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent",
                                   accessibilityDescription: "Desktop Overlay")
            button.image?.isTemplate = true
            button.toolTip = "Desktop Overlay"
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    // MARK: - Menu construction

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Desktop Overlay", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let visible = overlay?.isVisible ?? false
        menu.addItem(action("Show Overlay", #selector(showOverlay), enabled: !visible))
        menu.addItem(action("Hide Overlay", #selector(hideOverlay), enabled: visible))
        menu.addItem(.separator())

        menu.addItem(submenu("Metrics", items: menuMetrics.map { id in
            check(id.displayName, #selector(toggleMetric(_:)),
                  on: settings.enabledMetrics.contains(id), represented: id.rawValue)
        }))

        menu.addItem(submenu("Update Interval", items: UpdateInterval.allCases.map { interval in
            check(interval.label, #selector(setInterval(_:)),
                  on: settings.updateInterval == interval, represented: interval.rawValue)
        }))

        menu.addItem(check("Always on Top", #selector(toggleAlwaysOnTop), on: settings.alwaysOnTop))
        menu.addItem(check("Click Through", #selector(toggleClickThrough), on: settings.clickThrough))

        menu.addItem(submenu("Appearance", items: AppearanceMode.allCases.map { mode in
            check(mode.label, #selector(setAppearance(_:)),
                  on: settings.appearance == mode, represented: mode.rawValue)
        }))
        menu.addItem(.separator())

        menu.addItem(action("Settings…", #selector(openSettings), keyEquivalent: ","))
        menu.addItem(action("Reset Position", #selector(resetPosition)))
        menu.addItem(check("Launch at Login", #selector(toggleLaunchAtLogin), on: settings.launchAtLogin))
        menu.addItem(.separator())
        menu.addItem(action("Quit Desktop Overlay", #selector(quit), keyEquivalent: "q"))
    }

    // MARK: - Actions

    @objc private func showOverlay() { overlay?.showOverlay() }
    @objc private func hideOverlay() { overlay?.hideOverlay() }
    @objc private func resetPosition() { overlay?.resetPosition() }

    @objc private func toggleMetric(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = MetricID(rawValue: raw) else { return }
        settings.setMetric(id, enabled: !settings.enabledMetrics.contains(id))
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int,
              let interval = UpdateInterval(rawValue: raw) else { return }
        settings.updateInterval = interval
    }

    @objc private func toggleAlwaysOnTop() { settings.alwaysOnTop.toggle() }
    @objc private func toggleClickThrough() { settings.clickThrough.toggle() }

    @objc private func setAppearance(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = AppearanceMode(rawValue: raw) else { return }
        settings.appearance = mode
    }

    @objc private func toggleLaunchAtLogin() {
        // AppDelegate observes this and calls the ServiceManagement API.
        settings.launchAtLogin.toggle()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Item builders

    private func action(_ title: String,
                        _ selector: Selector,
                        keyEquivalent: String = "",
                        enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = enabled
        return item
    }

    private func check(_ title: String,
                       _ selector: Selector,
                       on: Bool,
                       represented: Any? = nil) -> NSMenuItem {
        let item = action(title, selector)
        item.state = on ? .on : .off
        item.representedObject = represented
        return item
    }

    private func submenu(_ title: String, items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu(title: title)
        sub.autoenablesItems = false
        items.forEach { sub.addItem($0) }
        parent.submenu = sub
        return parent
    }
}
