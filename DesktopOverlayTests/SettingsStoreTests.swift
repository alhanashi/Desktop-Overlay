import XCTest
@testable import DesktopOverlay

@MainActor
final class SettingsStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "DesktopOverlayTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsMatchSpecFirstRun() {
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.opacity, 0.85, accuracy: 0.0001)
        XCTAssertEqual(settings.updateInterval, .one)
        XCTAssertTrue(settings.alwaysOnTop)
        XCTAssertFalse(settings.clickThrough)
        XCTAssertEqual(settings.enabledMetrics, [.cpu, .memory, .disk, .network])
        XCTAssertEqual(settings.appearance, .system)
    }

    func testValuesRoundTripAcrossInstances() {
        do {
            let settings = SettingsStore(defaults: defaults)
            settings.opacity = 0.5
            settings.cornerRadius = 4
            settings.updateInterval = .five
            settings.alwaysOnTop = false
            settings.clickThrough = true
            settings.appearance = .dark
            settings.fontSize = .large
            settings.sizeMode = .compact
            settings.setMetric(.temperature, enabled: true)
            settings.setMetric(.disk, enabled: false)
        }

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.opacity, 0.5, accuracy: 0.0001)
        XCTAssertEqual(reloaded.cornerRadius, 4, accuracy: 0.0001)
        XCTAssertEqual(reloaded.updateInterval, .five)
        XCTAssertFalse(reloaded.alwaysOnTop)
        XCTAssertTrue(reloaded.clickThrough)
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertEqual(reloaded.fontSize, .large)
        XCTAssertEqual(reloaded.sizeMode, .compact)
        XCTAssertTrue(reloaded.enabledMetrics.contains(.temperature))
        XCTAssertFalse(reloaded.enabledMetrics.contains(.disk))
    }

    func testOverlayFrameRoundTrip() {
        let frame = CGRect(x: 12, y: 34, width: 240, height: 160)
        do {
            let settings = SettingsStore(defaults: defaults)
            settings.overlayFrame = frame
        }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.overlayFrame, frame)
    }

    func testInvalidOverlayFrameIsIgnored() {
        let settings = SettingsStore(defaults: defaults)
        XCTAssertNil(settings.overlayFrame)
        settings.overlayFrame = CGRect(x: 0, y: 0, width: 0, height: 0)
        XCTAssertNil(settings.overlayFrame)
    }

    func testSetMetricTogglesMembership() {
        let settings = SettingsStore(defaults: defaults)
        settings.setMetric(.battery, enabled: true)
        XCTAssertTrue(settings.isMetricEnabled(.battery))
        settings.setMetric(.battery, enabled: false)
        XCTAssertFalse(settings.isMetricEnabled(.battery))
    }
}
