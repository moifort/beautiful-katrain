#!/bin/bash
# Phase 0 : bundle jetable, signé et sandboxé, pour répondre à une seule question —
# KataGo peut-il atteindre le GPU en Metal depuis l'intérieur du sandbox App Store ?
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SDK="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk"
IDENTITY="Apple Development: Thibaut Mottet (4YXCH77688)"
APP="$ROOT/app/build/MoyoSpike.app"
KATAGO="$ROOT/vendor/katago-src/cpp/build-static/katago"
PAYLOAD="$ROOT/app/build/payload"
WORK="$ROOT/app/build/spike-work"

for path in "$KATAGO" "$PAYLOAD/python" "$PAYLOAD/bridge"; do
  [ -e "$path" ] || { echo "manque $path" >&2; exit 1; }
done

echo "==> Compilation de la sonde"
mkdir -p "$WORK"
"$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" \
  -O -sdk "$SDK" -target arm64-apple-macos26.0 \
  -o "$WORK/MoyoSpike" "$ROOT/app/Scripts/spike/main.swift"

echo "==> Assemblage"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources/models"
cp "$WORK/MoyoSpike" "$APP/Contents/MacOS/MoyoSpike"
cp "$KATAGO" "$APP/Contents/Helpers/katago"
cp -R "$PAYLOAD/python" "$APP/Contents/Resources/python"
cp -R "$PAYLOAD/bridge" "$APP/Contents/Resources/bridge"
cp "$ROOT/.venv/lib/python3.13/site-packages/katrain/KataGo/analysis_config.cfg" "$APP/Contents/Resources/"
cp /opt/homebrew/opt/katago/share/katago/kata1-b18c384nbt-s9996604416-d4316597426.bin.gz \
   "$APP/Contents/Resources/models/play.bin.gz"
cp "$HOME/.katrain/b18c384nbt-humanv0.bin.gz" "$APP/Contents/Resources/models/human.bin.gz"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>MoyoSpike</string>
  <key>CFBundleIdentifier</key><string>com.thibaut.moyo.spike</string>
  <key>CFBundleName</key><string>MoyoSpike</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
</dict></plist>
PLIST

# L'application est sandboxée ; les enfants héritent. Un enfant qui porte la
# moindre entitlement en plus de ces deux-là est tué au démarrage par le système.
cat > "$WORK/app.entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
</dict></plist>
PLIST
cat > "$WORK/helper.entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.inherit</key><true/>
</dict></plist>
PLIST

echo "==> Signature, de l'intérieur vers l'extérieur"
# Toute signature extérieure invalide les intérieures : l'ordre n'est pas négociable.
find "$APP/Contents/Resources/python" \( -name "*.so" -o -name "*.dylib" \) -print0 |
  while IFS= read -r -d '' lib; do
    codesign --force --timestamp --options runtime --sign "$IDENTITY" "$lib" 2>/dev/null
  done
echo "    $(find "$APP/Contents/Resources/python" \( -name '*.so' -o -name '*.dylib' \) | wc -l | tr -d ' ') bibliothèques signées"

# python-build-standalone ne porte pas d'Info.plist : sans --identifier, le système
# ne lui trouve pas d'identifiant de bundle et refuse de l'exécuter sous sandbox.
codesign --force --timestamp --options runtime \
  --identifier com.thibaut.moyo.spike.python \
  --entitlements "$WORK/helper.entitlements" --sign "$IDENTITY" \
  "$APP/Contents/Resources/python/bin/python3.13"
codesign --force --timestamp --options runtime \
  --identifier com.thibaut.moyo.spike.katago \
  --entitlements "$WORK/helper.entitlements" --sign "$IDENTITY" \
  "$APP/Contents/Helpers/katago"
codesign --force --timestamp --options runtime \
  --entitlements "$WORK/app.entitlements" --sign "$IDENTITY" "$APP"

echo "==> Vérification"
codesign --verify --deep --strict --verbose=1 "$APP"
echo "--- entitlements de katago ---"
codesign -d --entitlements - "$APP/Contents/Helpers/katago" 2>&1 | tail -n +2
echo "==> $APP ($(du -sm "$APP" | cut -f1) Mo)"
