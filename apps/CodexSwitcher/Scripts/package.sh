#!/bin/bash
set -e
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
SWIFT_DIR="$(cd "$SCRIPTS/.." && pwd)"
ROOT="$(cd "$SWIFT_DIR/../.." && pwd)"

# Load local credentials if available (not committed to git)
[ -f "$SCRIPTS/.env" ] && . "$SCRIPTS/.env"
RELEASE_DIR="$ROOT/release"
BUILD_DIR="$SWIFT_DIR/.build/arm64-apple-macosx/release"
APP_NAME="CodexSwitcher"
APP_BUNDLE="$APP_NAME.app"

# Signing — set these in your environment or a local .env file
#    CODE_SIGN_IDENTITY    e.g. "Developer ID Application: ..."
#    NOTARY_PROFILE        keychain profile for notarytool
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APP_VERSION="${APP_VERSION:-0.2.0}"

echo "=== 1. Building codex-auth (Zig) ==="
cd "$ROOT"
zig build -Doptimize=ReleaseFast

echo "=== 2. Copying codex-auth to Swift Resources ==="
cp "$ROOT/zig-out/bin/codex-auth" "$SWIFT_DIR/Sources/CodexSwitcher/Resources/codex-auth"
chmod +x "$SWIFT_DIR/Sources/CodexSwitcher/Resources/codex-auth"
BUNDLED_CLI_VERSION="$("$SWIFT_DIR/Sources/CodexSwitcher/Resources/codex-auth" --version --json 2>/dev/null | sed -E 's/.*"version":"([^"]+)".*/\1/')"
echo "Bundled CLI version: ${BUNDLED_CLI_VERSION:-unknown}"

echo "=== 3. Building CodexSwitcher (Swift release) ==="
cd "$SWIFT_DIR"
swift build -c release

echo "=== 4. Creating .app bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -R "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_BUNDLE/Contents/Resources/"
cp "$SCRIPTS/Info.plist" "$APP_BUNDLE/Contents/"
if [ -n "$BUNDLED_CLI_VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CodexSwitcherBundledCLIVersion ${BUNDLED_CLI_VERSION}" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_VERSION}" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Entitlements (hardened runtime)
cat > "$SCRIPTS/entitlements.plist" << ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
ENT

echo "=== 5. Code-signing ==="
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    codesign --sign "$CODE_SIGN_IDENTITY" --force --options=runtime --timestamp \
        "$APP_BUNDLE/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle/codex-auth" 2>/dev/null || true

    codesign --sign "$CODE_SIGN_IDENTITY" --force --deep --options=runtime --timestamp \
        --entitlements "$SCRIPTS/entitlements.plist" \
        "$APP_BUNDLE"

    codesign -dvv "$APP_BUNDLE" 2>&1 | grep "Authority" | head -1
else
    codesign --sign - --force --deep "$APP_BUNDLE" 2>/dev/null || true
    echo "(ad-hoc signed — set CODE_SIGN_IDENTITY for Developer ID)"
fi

echo "=== 6. Creating DMG ==="
rm -rf "$RELEASE_DIR/dmg_staging" "$RELEASE_DIR/${APP_NAME}-${APP_VERSION}.dmg"
mkdir -p "$RELEASE_DIR/dmg_staging"
cp -R "$APP_BUNDLE" "$RELEASE_DIR/dmg_staging/"
ln -sf /Applications "$RELEASE_DIR/dmg_staging/Applications"

DMG_PATH="$RELEASE_DIR/${APP_NAME}-${APP_VERSION}.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$RELEASE_DIR/dmg_staging" -ov -format UDZO "$DMG_PATH"

# Sign the DMG too
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    codesign --sign "$CODE_SIGN_IDENTITY" --force --options=runtime --timestamp "$DMG_PATH"
fi

echo "=== 7. Notarizing ==="
if [ -n "$NOTARY_PROFILE" ]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1
    echo "=== 8. Stapling ==="
    xcrun stapler staple "$DMG_PATH"
else
    echo "(skipped — set NOTARY_PROFILE to notarize)"
fi

# Cleanup
rm -rf "$RELEASE_DIR/dmg_staging" "$APP_BUNDLE"

echo ""
echo "=== Done ==="
echo "DMG:  $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "To install: open $DMG_PATH and drag CodexSwitcher to Applications"
