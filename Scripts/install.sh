#!/bin/bash
# Build DesktopOverlay (Release), install it to /Applications, ad-hoc sign it,
# and launch it. Installing to a stable, signed location is what lets
# "Launch at Login" (SMAppService) actually register.
#
#   ./Scripts/install.sh
#
# No sudo needed unless your /Applications is locked down.

set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="DesktopOverlay.xcodeproj"
SCHEME="DesktopOverlay"
DEST="/Applications/DesktopOverlay.app"
BUILD_DIR="$(pwd)/.build-release"

echo "▸ Building $SCHEME (Release)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build >/dev/null

APP="$BUILD_DIR/Build/Products/Release/DesktopOverlay.app"
[ -d "$APP" ] || { echo "✗ Build product not found at $APP"; exit 1; }

echo "▸ Stopping any running instance…"
pkill -f "DesktopOverlay.app/Contents/MacOS/DesktopOverlay" 2>/dev/null || true
sleep 1

echo "▸ Installing to $DEST…"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "▸ Ad-hoc signing…"
codesign --force --deep --sign - "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "▸ Launching…"
open "$DEST"

echo ""
echo "✓ Installed. The overlay and the menu bar icon should appear."
echo "  Enable 'Launch at Login' from the menu bar or Settings ▸ General."
echo "  Verify in  System Settings ▸ General ▸ Login Items."
