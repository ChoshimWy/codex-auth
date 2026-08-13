#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SWIFT_DIR="$ROOT/apps/CodexSwitcher"

echo "=== Building codex-auth (Zig) ==="
cd "$ROOT"
zig build -Doptimize=ReleaseFast

echo "=== Copying codex-auth to Swift Resources ==="
cp "$ROOT/zig-out/bin/codex-auth" "$SWIFT_DIR/Sources/CodexSwitcher/Resources/codex-auth"
chmod +x "$SWIFT_DIR/Sources/CodexSwitcher/Resources/codex-auth"

echo "=== Building CodexSwitcher (Swift) ==="
cd "$SWIFT_DIR"
swift build -c release

echo "=== Done ==="
echo "Release binary: $SWIFT_DIR/.build/arm64-apple-macosx/release/CodexSwitcher"
echo ""
echo "To create a distributable package:"
echo "  mkdir -p CodexSwitcher.app/Contents/MacOS"
echo "  cp .build/arm64-apple-macosx/release/CodexSwitcher CodexSwitcher.app/Contents/MacOS/"
