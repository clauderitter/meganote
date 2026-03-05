#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Meganote"
BUILD_DIR=".build"
APP_BUNDLE="$APP_NAME.app"

echo "Building $APP_NAME..."

# Build with SPM
swift build -c release 2>&1

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy app icon
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Ad-hoc code sign
codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "Build complete: $APP_BUNDLE"
echo "To run: open $APP_BUNDLE"
