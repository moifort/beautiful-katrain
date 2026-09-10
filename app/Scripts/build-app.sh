#!/bin/bash
# Builds BeautifulKaTrain.app.
#
# The milestone runs the bridge from the project's virtual environment rather than
# embedding a Python interpreter, so the project root is baked into Info.plist and
# the app is not relocatable. Bundling the interpreter is a later milestone.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$APP_DIR/.." && pwd)"
CONFIGURATION="${1:-release}"
BUNDLE="$APP_DIR/build/BeautifulKaTrain.app"

echo "==> Building ($CONFIGURATION)"
swift build --package-path "$APP_DIR" -c "$CONFIGURATION"
BINARY="$(swift build --package-path "$APP_DIR" -c "$CONFIGURATION" --show-bin-path)/BeautifulKaTrain"

echo "==> Assembling bundle"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/BeautifulKaTrain"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>BeautifulKaTrain</string>
    <key>CFBundleIdentifier</key><string>com.thibaut.beautifulkatrain</string>
    <key>CFBundleName</key><string>Beautiful KaTrain</string>
    <key>CFBundleDisplayName</key><string>Beautiful KaTrain</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>BKTProjectRoot</key><string>$PROJECT_ROOT</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for local launching, not for distribution.
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || echo "    (signature ad-hoc ignorée)"

echo "==> $BUNDLE"
