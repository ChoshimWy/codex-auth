#!/bin/bash
set -e
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
SWIFT_DIR="$(cd "$SCRIPTS/.." && pwd)"
ROOT="$(cd "$SWIFT_DIR/../.." && pwd)"
RELEASE_DIR="$ROOT/release"
BUILD_DIR="$SWIFT_DIR/.build/arm64-apple-macosx/release"
APP_NAME="CodexSwitcher"
APP_BUNDLE="$APP_NAME.app"
DIST_DIR="$SWIFT_DIR/dist"

echo "=== 1. Building codex-auth (Zig) ==="
cd "$ROOT"
zig build -Doptimize=ReleaseFast

echo "=== 2. Copying codex-auth to Swift Resources ==="
cp "$ROOT/zig-out/bin/codex-auth" "$SWIFT_DIR/Sources/CodexSwitcher/Resources/codex-auth"
chmod +x "$SWIFT_DIR/Sources/CodexSwitcher/Resources/codex-auth"

echo "=== 3. Building CodexSwitcher (Swift release) ==="
cd "$SWIFT_DIR"
swift build -c release

echo "=== 4. Creating .app bundle ==="
rm -rf "$DIST_DIR" "$APP_BUNDLE"
mkdir -p "$DIST_DIR"

# App bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy resource bundle
cp -R "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_BUNDLE/Contents/Resources/"

# Copy Info.plist
cp "$SCRIPTS/Info.plist" "$APP_BUNDLE/Contents/"

# Copy PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "=== 5. Code-signing ==="
# Ad-hoc sign (no hardened runtime — notarization not needed for personal distribution)
codesign --sign - --force --deep \
    "$APP_BUNDLE/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle/codex-auth" 2>/dev/null || true
codesign --sign - --force --deep \
    "$APP_BUNDLE" 2>/dev/null || true

echo "=== 6. Creating DMG ==="
mkdir -p "$DIST_DIR/dmg"
cp -R "$APP_BUNDLE" "$DIST_DIR/dmg/"
ln -sf /Applications "$DIST_DIR/dmg/Applications"

DMG_NAME="${APP_NAME}-0.1.0.dmg"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DIST_DIR/dmg" \
    -ov -format UDZO \
    "$DIST_DIR/$DMG_NAME"

# Cleanup
rm -rf "$DIST_DIR/dmg" "$APP_BUNDLE"

echo ""
echo "=== Done ==="
echo "DMG:  $DIST_DIR/$DMG_NAME"
echo "Size: $(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)"
echo ""
echo "To install: open $DIST_DIR/$DMG_NAME and drag CodexSwitcher to Applications"
