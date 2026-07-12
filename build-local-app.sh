#!/bin/bash
set -euo pipefail

APP_NAME="VoiceScribe Local"
APP_BUNDLE="dist/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
BUILD_DIR=".build/release"

swift build -c release --product VoiceScribe

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

cp "${BUILD_DIR}/VoiceScribe" "$MACOS/VoiceScribe"
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp Resources/VoiceScribe.entitlements "$RESOURCES/VoiceScribe.entitlements"
cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.voicescribe.local" "$CONTENTS/Info.plist"

find "$BUILD_DIR" -maxdepth 1 -type d -name '*.bundle' -exec cp -R '{}' "$RESOURCES/" ';'

codesign --force --deep --sign - \
    --entitlements Resources/VoiceScribe.entitlements \
    "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
echo "Built ${APP_BUNDLE}"
