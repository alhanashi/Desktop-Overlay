#!/bin/bash
# Build a distributable zip of DesktopOverlay.app to attach to a GitHub Release.
#
#   ./Scripts/package.sh
#
# Output: dist/DesktopOverlay-<version>.zip
#
# The build is ad-hoc signed, NOT notarized. First launch on another Mac:
# right-click the app ▸ Open ▸ Open (or `xattr -dr com.apple.quarantine`).

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep -m1 'MARKETING_VERSION:' project.yml | sed -E 's/.*: *"?([^"]+)"?.*/\1/')"
[ -n "$VERSION" ] || VERSION="1.0"

BUILD_DIR="$(pwd)/.build-release"
DIST="$(pwd)/dist"
ZIP="$DIST/DesktopOverlay-$VERSION.zip"

echo "▸ Building DesktopOverlay $VERSION (Release)…"
xcodebuild -project DesktopOverlay.xcodeproj -scheme DesktopOverlay -configuration Release \
    -derivedDataPath "$BUILD_DIR" build >/dev/null

APP="$BUILD_DIR/Build/Products/Release/DesktopOverlay.app"
[ -d "$APP" ] || { echo "✗ build product not found at $APP"; exit 1; }

echo "▸ Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "▸ Zipping…"
mkdir -p "$DIST"
rm -f "$ZIP"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/DesktopOverlay.app"
( cd "$STAGE" && ditto -c -k --sequesterRsrc --keepParent DesktopOverlay.app "$ZIP" )
rm -rf "$STAGE" "$BUILD_DIR"

echo ""
echo "✓ $ZIP"
echo "  → GitHub ▸ Releases ▸ Draft a new release ▸ tag v$VERSION ▸ attach this file."
