#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=".build/FrameExtractor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/FrameExtractor" "$APP/Contents/MacOS/FrameExtractor"
cp "Info.plist" "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP"

DEST="$HOME/Applications/FrameExtractor.app"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "Built $DEST"
