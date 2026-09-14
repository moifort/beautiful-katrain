#!/bin/bash
# Builds Moyo.app.
#
# The milestone runs the bridge from the project's virtual environment rather than
# embedding a Python interpreter, so the project root is baked into Info.plist and
# the app is not relocatable. Bundling the interpreter is a later milestone.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$APP_DIR/.." && pwd)"
CONFIGURATION="${1:-release}"
BUNDLE="$APP_DIR/build/Moyo.app"

echo "==> Building ($CONFIGURATION)"
swift build --package-path "$APP_DIR" -c "$CONFIGURATION"
BINARY="$(swift build --package-path "$APP_DIR" -c "$CONFIGURATION" --show-bin-path)/Moyo"

echo "==> Assembling bundle"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/Moyo"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Moyo</string>
    <key>CFBundleIdentifier</key><string>com.thibaut.moyo</string>
    <key>CFBundleName</key><string>Moyo</string>
    <key>CFBundleDisplayName</key><string>Moyo</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>MoyoProjectRoot</key><string>$PROJECT_ROOT</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for local launching, not for distribution.
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || echo "    (signature ad-hoc ignorée)"

echo "==> $BUNDLE"
