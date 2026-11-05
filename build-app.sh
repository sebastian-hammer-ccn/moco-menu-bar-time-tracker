#!/usr/bin/env bash
# Baut MocoBar und erzeugt das App-Bundle MocoBar.app im Projektordner.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/MocoBar"

rm -rf MocoBar.app
mkdir -p MocoBar.app/Contents/MacOS
cp "$BIN" MocoBar.app/Contents/MacOS/MocoBar

mkdir -p MocoBar.app/Contents/Resources
cp Resources/AppIcon.icns MocoBar.app/Contents/Resources/AppIcon.icns

cat > MocoBar.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MocoBar</string>
    <key>CFBundleIdentifier</key><string>local.mocobar</string>
    <key>CFBundleExecutable</key><string>MocoBar</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign -s - --force MocoBar.app
echo "Fertig: $(pwd)/MocoBar.app"
