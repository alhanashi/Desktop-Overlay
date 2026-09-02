# Desktop Overlay

A tiny, native macOS floating panel that shows live system metrics — CPU, memory,
disk I/O, network throughput, and thermal state — always on top of your other
windows, so you never need to open Activity Monitor.

- 100% native: **Swift + SwiftUI + AppKit**. No Electron, no web view, no
  JavaScript, no Python, no bundled runtime.
- **Local only.** No network connections, no database, no telemetry, no
  analytics. Settings live in `UserDefaults`.
- Energy-aware: one background timer, collection paused while hidden, update
  rate automatically stretched under thermal pressure.

---

## Requirements

| | |
|---|---|
| macOS | **15.0** or later (built and tested on macOS 26) |
| Xcode | 16 or later (developed with Xcode 26.5) |
| Signing | None required for personal use — runs ad-hoc signed. App Sandbox is **off** (see *Known limitations*). |
| Dependencies | None. Only Apple system frameworks. |

[XcodeGen](https://github.com/yonaskolb/XcodeGen) is used to generate the project
from `project.yml`, but the generated `DesktopOverlay.xcodeproj` is committed, so
you do **not** need XcodeGen installed to build or run.

---

## Open, build, run

```bash
open "DesktopOverlay.xcodeproj"
```

Then in Xcode: select the **DesktopOverlay** scheme and press **⌘R**.

On launch:

- the overlay appears immediately, centred on the main screen (~220×140 pt);
- a **gauge** icon appears in the menu bar;
- nothing appears in the Dock (the app is an accessory / `LSUIElement`).

Command line:

```bash
# build
xcodebuild -project DesktopOverlay.xcodeproj -scheme DesktopOverlay -configuration Debug build

# run the unit tests (33 tests)
xcodebuild -project DesktopOverlay.xcodeproj -scheme DesktopOverlay -destination 'platform=macOS' test
```

To regenerate the project after editing `project.yml`:

```bash
xcodegen generate
```

---

## Using it

| Action | How |
|---|---|
| Move | Drag anywhere on the panel |
| Resize | Drag the ⤡ grip in the bottom-right corner |
| Open Settings | Menu bar ▸ **Settings…** (or ⌘, when a window is focused) |
| Hide / show | Menu bar ▸ **Hide Overlay** / **Show Overlay** |
| Keep above everything | Menu bar ▸ **Always on Top** (on by default) |
| Let clicks pass through | Menu bar ▸ **Click Through** |
| Change what's shown | Menu bar ▸ **Metrics**, or the Settings ▸ Metrics tab |
| Show CPU °C / fan RPM | Settings ▸ Metrics ▸ **Sensors (SMC)** — off by default, Intel Macs only (see *Known limitations*) |
| Change refresh rate | Menu bar ▸ **Update Interval** (1 / 2 / 5 s) |
| Start with macOS | Menu bar ▸ **Launch at Login**, or Settings ▸ General |
| Recenter if lost | Menu bar ▸ **Reset Position** |

All settings — position, size, opacity, corner radius, font size, selected
metrics, update interval, appearance, always-on-top, click-through,
launch-at-login — persist across relaunches.

---

## Architecture

```
DesktopOverlay/
├── App/          DesktopOverlayApp (@main), AppDelegate (lifecycle §23)
├── Overlay/      OverlayPanel (NSPanel), OverlayWindowController,
│                 OverlayView / OverlayRowView / SparklineView
├── Metrics/      MetricValue, SystemMetric (protocol), MetricsCoordinator,
│                 CPUMetric, MemoryMetric, DiskMetric, NetworkMetric,
│                 ThermalMetric, BatteryMetric
├── Settings/     SettingsStore (UserDefaults, single source of truth),
│                 SettingsView (General / Appearance / Metrics / Update)
├── MenuBar/      MenuBarController (NSStatusItem + NSMenu)
├── Services/     SystemMetricsService (Mach / IOKit / POSIX wrappers),
│                 LaunchAtLoginService (SMAppService)
└── Utilities/    RingBuffer, RateCalculator, CPUCalculator, MemoryCalculator,
                  DecayingMax, OverlayGeometry, MetricFormatter
```

**Data flow**

1. `MetricsCoordinator` owns one `DispatchSourceTimer` on a `.utility` queue.
2. Each tick samples the enabled `SystemMetric`s **off the main thread**, builds
   an immutable frame, and hops to the main actor once to publish it.
3. SwiftUI views observe `MetricsCoordinator` and `SettingsStore` and re-render
   only on change. Sparklines are `Canvas`-drawn with no animation.
4. Under `.serious` / `.critical` thermal state the effective interval is
   multiplied ×2 / ×4 and sparkline updates pause.

The pure calculation helpers (`CPUCalculator`, `MemoryCalculator`,
`RateCalculator`, `OverlayGeometry`, `RingBuffer`) contain no I/O and are covered
by unit tests in `DesktopOverlayTests/`.

---

## Adding a new metric

Example: a **Swap** metric.

1. **Identifier** — add a case to `MetricID` in
   `DesktopOverlay/Metrics/MetricValue.swift` (plus `shortLabel` / `displayName`
   and a spot in `displayOrder`).
2. **Raw reader** — add a function to `SystemMetricsService` that returns the raw
   counters via a *public* API, `nil` on failure.
3. **Metric object** — create `SwapMetric.swift` implementing `SystemMetric`.
   Keep any previous raw sample privately for delta-based values; put the pure
   math in a `Utilities/` helper so it can be unit-tested.
4. **Register** — add `.swap: SwapMetric()` to the `metrics` dictionary in
   `MetricsCoordinator`.
5. **Expose** — add a `Toggle` to `MetricsSettingsTab` in `SettingsView.swift`
   (and, if it belongs in the quick menu, to `menuMetrics` in
   `MenuBarController`).
6. **Display** — `OverlayRowView` / `MetricFormatter` already render
   `percent` / `bytes` / `bytesPerSecond` / `text`; only touch them if the new
   metric needs a bespoke layout.

No other part of the app needs to change.

---

## Creating a release

1. Set a real bundle identifier / team in `project.yml` if distributing, then
   `xcodegen generate`.
2. **Product ▸ Archive** (Release configuration).
3. In the Organizer, **Distribute App ▸ Direct Distribution** (Developer ID) to
   get a signed `.app`.
4. Optional but recommended for sharing:
   ```bash
   xcrun notarytool submit DesktopOverlay.zip --apple-id <id> --team-id <team> --password <app-specific-pw> --wait
   xcrun stapler staple DesktopOverlay.app
   ```
5. Package the `.app` (or a DMG) and distribute.

---

## Known limitations

Everything here is a deliberate consequence of using **public APIs only**
(spec §20):

| Metric | Public API status | What the app does |
|---|---|---|
| **Thermal state** | `ProcessInfo.thermalState` — public. | Shown as **Nominal / Fair / Serious / Critical** (the *Temperature* metric, on by default). |
| **CPU temperature (°C)** | No *documented* API. Readable from the **SMC** on Intel Macs via undocumented keys. | Optional **Sensors (SMC)** metric, **off by default**. Uses `SMCService`; see below. Apple Silicon reports "unavailable". |
| **Fan RPM** | Same as CPU °C — SMC only, undocumented. | Optional **Sensors (SMC)** metric, off by default. |
| **GPU usage** | No public API for system-wide GPU load. | Architecture-ready (`SystemMetric`); the Settings toggle is disabled with an explanation. |
| **CPU frequency** | No reliable public API. | Not implemented; can be added without redesign. |
| **Battery** | `IOPSCopyPowerSourcesInfo` — public. | Implemented (`BatteryMetric`), off by default to keep the overlay small. Desktops report "unavailable". |
| **Disk I/O** | `IOBlockStorageDriver` statistics via IOKit — public, **but blocked by App Sandbox**. | App Sandbox is disabled. If you re-enable it, the Disk row degrades to `—`; every other metric still works. |

### Optional SMC sensors

`DesktopOverlay/Services/SMCService.swift` reads CPU temperature and fan speed
from the System Management Controller. This is **not a documented Apple API** —
the 4-character keys (`TC0P`, `F0Ac`, …) and their encodings (`sp78`, `fpe2`,
`flt`) are community-reverse-engineered. It is included because a system monitor
without a temperature reading is of limited use, and every comparable tool
(iStat Menus, TG Pro, Stats) does the same.

- **Off by default.** Enable per-metric in Settings ▸ Metrics ▸ *Sensors (SMC)*.
- **No special privileges.** No root, no SIP/Gatekeeper changes, no kext.
- **May break on a future macOS** — if a key stops responding the row shows `—`
  and nothing else is affected.
- **Isolated.** Delete `SMCService.swift`, `SMCTemperatureMetric.swift` and
  `FanMetric.swift`, drop the two `MetricID` cases, and the app is back to
  100% documented APIs.

The app makes **zero** network connections and stores nothing outside
`UserDefaults`.

---

## Manual test checklist (spec §28)

Run through these after UI changes:

- [ ] Light mode / Dark mode / System
- [ ] Retina and non-Retina displays
- [ ] Two or more displays; disconnect one → overlay returns to the primary screen
- [ ] Full-screen app in front → overlay stays visible, Dock/menu bar don't appear
- [ ] Drag to each screen edge; quit and relaunch → position restored
- [ ] Resize to min and max
- [ ] Click Through on → clicks reach the app behind; off → overlay interactive
- [ ] Always on Top on/off
- [ ] Opacity, corner radius, font size, compact/normal all apply live
- [ ] Launch at Login on → appears in System Settings ▸ General ▸ Login Items
- [ ] Leave running for hours → check CPU ≈ idle, memory flat, Energy = Low in
      Activity Monitor / Instruments
