#!/bin/bash
set -e

APP_NAME="VoiceScribe"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Parse arguments
UNIVERSAL=false
SIGN_IDENTITY=""
RELEASE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --universal) UNIVERSAL=true ;;
        --sign) SIGN_IDENTITY="$2"; shift ;;
        --release) RELEASE=true ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo "Building $APP_NAME..."

if [ "$UNIVERSAL" = true ]; then
    echo "Building universal binary (arm64 + x86_64)..."

    # Build for arm64
    echo "  Building for arm64..."
    swift build -c release --arch arm64

    # Build for x86_64
    echo "  Building for x86_64..."
    swift build -c release --arch x86_64

    # Create universal binary with lipo
    echo "  Creating universal binary..."
    mkdir -p .build/universal
    lipo -create \
        .build/arm64-apple-macosx/release/$APP_NAME \
        .build/x86_64-apple-macosx/release/$APP_NAME \
        -output .build/universal/$APP_NAME

    BINARY_PATH=".build/universal/$APP_NAME"
else
    swift build -c release
    BINARY_PATH=".build/release/$APP_NAME"
fi

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

cp "$BINARY_PATH" "$MACOS/"
cp "Resources/Info.plist" "$CONTENTS/"
cp "Resources/VoiceScribe.entitlements" "$RESOURCES/"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES/"
fi

echo "Code signing app bundle..."
if [ -n "$SIGN_IDENTITY" ]; then
    codesign --force --deep --sign "$SIGN_IDENTITY" \
        --entitlements "Resources/VoiceScribe.entitlements" \
        --options runtime \
        "$APP_BUNDLE"
else
    # Ad-hoc signing for distribution without developer certificate
    codesign --force --deep --sign - \
        --entitlements "Resources/VoiceScribe.entitlements" \
        "$APP_BUNDLE"
fi

echo "Verifying signature..."
codesign -dv --verbose=2 "$APP_BUNDLE" 2>&1 | grep -E "(Signature|TeamIdentifier|Authority|Identifier)" || true

if [ "$UNIVERSAL" = true ]; then
    echo "Verifying universal binary architectures..."
    lipo -info "$MACOS/$APP_NAME"
fi

if [ "$RELEASE" = true ]; then
    echo "Creating release archive..."
    VERSION=$(grep -A1 "CFBundleShortVersionString" Resources/Info.plist | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    ZIP_NAME="${APP_NAME}-${VERSION}-universal.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"
    echo "Created: $ZIP_NAME"

    # Calculate SHA256
    shasum -a 256 "$ZIP_NAME"
fi

echo ""
echo "Done! App bundle created: $APP_BUNDLE"
echo ""
echo "Usage:"
echo "  Local install:     cp -r $APP_BUNDLE /Applications/"
echo "  Universal build:   ./build-app.sh --universal"
echo "  Signed build:      ./build-app.sh --sign \"Developer ID Application: Name (TEAMID)\""
echo "  Release archive:   ./build-app.sh --universal --release"
