#!/bin/bash
set -e

APP_NAME="VoiceScribe"
VERSION=$(grep -A1 "CFBundleShortVersionString" Resources/Info.plist | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="dmg_temp"
VOLUME_NAME="${APP_NAME} ${VERSION}"

# Parse arguments
SIGN_IDENTITY=""
UNIVERSAL=false
NOTARIZE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sign) SIGN_IDENTITY="$2"; shift ;;
        --universal) UNIVERSAL=true ;;
        --notarize) NOTARIZE=true ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo "Building ${APP_NAME} DMG..."
echo "Version: ${VERSION}"

# Build the app
if [ "$UNIVERSAL" = true ]; then
    if [ -n "$SIGN_IDENTITY" ]; then
        ./build-app.sh --universal --sign "$SIGN_IDENTITY"
    else
        ./build-app.sh --universal
    fi
    DMG_NAME="${APP_NAME}-${VERSION}-universal.dmg"
else
    if [ -n "$SIGN_IDENTITY" ]; then
        ./build-app.sh --sign "$SIGN_IDENTITY"
    else
        ./build-app.sh
    fi
fi

# Clean up any existing temp directory and DMG
rm -rf "$DMG_TEMP"
rm -f "$DMG_NAME"

# Create temp directory structure
mkdir -p "$DMG_TEMP"
cp -r "${APP_NAME}.app" "$DMG_TEMP/"

# Create symbolic link to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create a background image with instructions (optional - using text file instead)
cat > "$DMG_TEMP/.background_info.txt" << 'EOF'
Drag VoiceScribe to Applications to install.
EOF

# Create the DMG
echo "Creating DMG..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_NAME"

# Clean up temp directory
rm -rf "$DMG_TEMP"

# Sign the DMG if we have an identity
if [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing DMG..."
    codesign --force --sign "$SIGN_IDENTITY" "$DMG_NAME"

    # Notarize if requested
    if [ "$NOTARIZE" = true ]; then
        echo "Submitting for notarization..."
        echo "Note: You need to have notarytool credentials configured."
        echo "Run: xcrun notarytool store-credentials"
        xcrun notarytool submit "$DMG_NAME" --keychain-profile "notarytool-profile" --wait

        echo "Stapling notarization ticket..."
        xcrun stapler staple "$DMG_NAME"
    fi
fi

# Calculate checksums
echo ""
echo "DMG created: $DMG_NAME"
echo ""
echo "Checksums:"
shasum -a 256 "$DMG_NAME"
echo ""
ls -lh "$DMG_NAME"
echo ""
echo "Usage:"
echo "  Basic build:           ./build-dmg.sh"
echo "  Universal + signed:    ./build-dmg.sh --universal --sign \"Developer ID Application: Name (TEAMID)\""
echo "  With notarization:     ./build-dmg.sh --universal --sign \"...\" --notarize"
