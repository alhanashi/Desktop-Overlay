# Changelog

## v1.0 — unreleased

First public release.

- Floating, always-on-top overlay showing **CPU**, **memory** (+ pressure),
  **disk I/O**, **network** throughput and **thermal state**. Drag anywhere to
  move; corner grip to resize.
- Optional **SMC sensors** on Intel Macs — **CPU temperature (°C)** and
  **fan RPM** — with a plain-language status hint (`cool` / `warm` / `hot`,
  `idle` / `moderate` / `high`) scaled against the fan's real range.
- Raw figures next to the percentages in Normal size (`13.6 / 32 GB` for RAM,
  the user/system split for CPU).
- Menu bar item and a native **Settings** window: General / Appearance / Metrics
  / Update / **Guide** (explains every metric and status word).
- Configurable opacity, corner radius, font size, Compact / Normal, update
  interval (1 / 2 / 5 s), appearance (System / Light / Dark), always-on-top,
  click-through, Launch at Login. Every setting persists across relaunches.
- Multi-display aware — recenters on the main screen if a saved position ends up
  off every display.
- **Energy-aware:** one background timer, collection paused while hidden,
  interval stretched ×2 / ×4 under thermal pressure. ~0.3 % CPU and ~45 MB RAM
  while idle.
- 100 % native (Swift / SwiftUI / AppKit), **zero dependencies, no network, no
  telemetry**. Public APIs only, apart from the isolated, opt-in SMC module.
- 40 unit tests.
