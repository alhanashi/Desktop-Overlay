# Contributing

Thanks for your interest in Desktop Overlay.

## Ground rules

- **Do not push to `main`.** It is protected. Work on a branch and open a pull
  request.
- Keep the app **dependency-free** and **public-API only**. The single allowed
  exception is the isolated, opt-in SMC sensor module (`Services/SMCService.swift`);
  new undocumented-API usage will not be merged.
- **No network, no telemetry, no analytics, no database.** Ever.

## Workflow

```bash
git switch -c my-change
# ... edit ...
xcodebuild -project DesktopOverlay.xcodeproj -scheme DesktopOverlay \
  -destination 'platform=macOS' test        # 40 tests must stay green
git push -u origin my-change
```

Then open a PR against `main`.

If you changed `project.yml`, run `xcodegen generate` and commit the regenerated
`DesktopOverlay.xcodeproj`.

## What a good PR looks like

- One focused change per PR.
- New logic that can be a pure function goes in `Utilities/` with unit tests in
  `DesktopOverlayTests/`.
- No new compiler warnings; Debug **and** Release must build clean.
- UI changes: run the manual checklist at the end of the README.
- Adding a metric: follow the "Adding a new metric" section of the README.

## Reporting bugs

Open an issue with your macOS version, your Mac model (Intel / Apple Silicon),
and steps to reproduce. For a wrong reading, include what Activity Monitor / a
comparable tool shows for the same moment.
