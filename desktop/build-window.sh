#!/bin/bash
#
# build-window.sh — rebuild Contents/MacOS/DeepSeekHarness from DSHWindow.swift.
#
# Run it after editing DSHWindow.swift:
#   "/Applications/DeepSeek Harness.app/Contents/Resources/build-window.sh"

set -eu

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SELF_DIR/../.." && pwd)"
OUT="$APP_ROOT/Contents/MacOS/DeepSeekHarness"
ARCH="$(/usr/bin/uname -m)"

WORK="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

/usr/bin/xcrun swiftc \
	-O \
	-parse-as-library \
	-target "${ARCH}-apple-macosx13.0" \
	-module-cache-path "$WORK/modulecache" \
	-framework Cocoa \
	-framework WebKit \
	-o "$WORK/DeepSeekHarness" \
	"$SELF_DIR/DSHWindow.swift"

/usr/bin/install -m 755 "$WORK/DeepSeekHarness" "$OUT"
/usr/bin/codesign --force --sign - --timestamp=none "$APP_ROOT"
echo "built $OUT"
