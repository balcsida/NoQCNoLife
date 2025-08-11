#!/bin/bash

# Script to create a DMG file for NoQCNoLife
# Usage: ./scripts/create-dmg.sh [version]

set -e

# Get version from argument or Info.plist
if [ -n "$1" ]; then
    VERSION=$1
else
    VERSION=$(defaults read "$(pwd)/NoQCNoLife/Info.plist" CFBundleShortVersionString)
fi

echo "Building NoQCNoLife version $VERSION..."

# Clean and build
echo "Building Release configuration..."
xcodebuild clean build \
    -project NoQCNoLife.xcodeproj \
    -scheme NoQCNoLife \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Create temporary directory for DMG contents
echo "Preparing DMG contents..."
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy app to temp directory
cp -R "build/Build/Products/Release/NoQCNoLife.app" "$TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TEMP_DIR/Applications"

# Create README
cat > "$TEMP_DIR/README.txt" << EOF
No QC, No Life v$VERSION
========================

Installation:
1. Drag "NoQCNoLife.app" to the Applications folder
2. Launch from Applications
3. Grant Bluetooth permissions when prompted

The app will appear in your menu bar.

Supported Devices:
- Bose QuietComfort 35
- Bose QuietComfort 35 Series II  
- Bose SoundWear Companion

For more information:
https://github.com/balcsida/NoQCNoLife

EOF

# Create DMG
DMG_NAME="NoQCNoLife-${VERSION}.dmg"
echo "Creating $DMG_NAME..."

# Remove old DMG if it exists
[ -f "$DMG_NAME" ] && rm "$DMG_NAME"

# Create DMG with nice volume name
hdiutil create -volname "NoQCNoLife $VERSION" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

# Calculate checksum
echo "Calculating checksum..."
shasum -a 256 "$DMG_NAME" | tee "${DMG_NAME}.sha256"

echo ""
echo "✅ DMG created successfully: $DMG_NAME"
echo "📊 Size: $(du -h "$DMG_NAME" | cut -f1)"
echo "🔐 SHA256: $(cat "${DMG_NAME}.sha256" | cut -d' ' -f1)"
echo ""
echo "To create a release:"
echo "1. git tag -a v${VERSION} -m 'Release v${VERSION}'"
echo "2. git push origin v${VERSION}"
echo "3. The GitHub Action will automatically create the release"