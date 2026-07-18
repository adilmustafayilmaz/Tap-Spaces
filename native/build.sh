#!/bin/bash
# Builds TapSpaces.app. Pass --install to also copy it into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="TapSpaces"
BUNDLE_ID="com.mustafa.tapspaces"
OUT="build/${APP_NAME}.app"

echo "==> Derleniyor (release)"
swift build -c release

echo "==> Self-test"
.build/release/"${APP_NAME}" --selftest

echo "==> İkon üretiliyor"
rm -rf icon/AppIcon.iconset
swift icon/make-icon.swift icon/AppIcon.iconset > /dev/null
iconutil -c icns icon/AppIcon.iconset -o icon/AppIcon.icns

echo "==> Bundle hazırlanıyor"
rm -rf "${OUT}"
mkdir -p "${OUT}/Contents/MacOS" "${OUT}/Contents/Resources"
cp ".build/release/${APP_NAME}" "${OUT}/Contents/MacOS/${APP_NAME}"
cp icon/AppIcon.icns "${OUT}/Contents/Resources/AppIcon.icns"

cat > "${OUT}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>Tap Spaces</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- Menu bar only: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Masaya vurduğun noktayı tespit etmek için mikrofonu dinler. Ses kaydedilmez veya gönderilmez.</string>
</dict>
</plist>
PLIST

echo "==> İmzalanıyor (ad-hoc)"
codesign --force --sign - --identifier "${BUNDLE_ID}" "${OUT}"
codesign --verify --verbose=1 "${OUT}" 2>&1 | sed 's/^/    /'

echo "==> Hazır: $(pwd)/${OUT}"

if [[ "${1:-}" == "--install" ]]; then
    echo "==> /Applications içine kopyalanıyor"
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${OUT}" /Applications/
    echo "==> Kuruldu: /Applications/${APP_NAME}.app"
fi
