#!/bin/bash

# Script to create a DMG file for NoQCNoLife using create-dmg
# Usage: ./scripts/create-dmg.sh [version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get version from argument or Info.plist
if [ -n "$1" ]; then
    VERSION=$1
else
    VERSION=$(defaults read "$(pwd)/NoQCNoLife/Info.plist" CFBundleShortVersionString)
fi

echo "Building NoQCNoLife version $VERSION..."

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}create-dmg is not installed. Installing via npm...${NC}"
    npm install -g create-dmg
    
    if ! command -v create-dmg &> /dev/null; then
        echo -e "${RED}Failed to install create-dmg. Please install it manually:${NC}"
        echo "  npm install -g create-dmg"
        echo "  or"
        echo "  brew install create-dmg"
        exit 1
    fi
fi

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

# Path to built app
APP_PATH="build/Build/Products/Release/NoQCNoLife.app"

# Verify app was built
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    exit 1
fi

# DMG output name
DMG_NAME="NoQCNoLife-${VERSION}.dmg"

# Remove old DMG if it exists
[ -f "$DMG_NAME" ] && rm "$DMG_NAME"

# Create DMG using create-dmg
echo "Creating DMG with create-dmg..."

# Create-dmg will automatically:
# - Create a beautiful DMG with the app icon
# - Add an Applications folder alias
# - Set up drag-and-drop installation
# - Optimize the DMG size

create-dmg \
    --volname "NoQCNoLife $VERSION" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "NoQCNoLife.app" 150 185 \
    --hide-extension "NoQCNoLife.app" \
    --app-drop-link 450 185 \
    --no-internet-enable \
    "$DMG_NAME" \
    "$APP_PATH"

# Check if DMG was created
if [ ! -f "$DMG_NAME" ]; then
    echo -e "${RED}Error: Failed to create DMG${NC}"
    exit 1
fi

# Calculate checksum
echo "Calculating checksum..."
shasum -a 256 "$DMG_NAME" | tee "${DMG_NAME}.sha256"

echo ""
echo -e "${GREEN}✅ DMG created successfully: $DMG_NAME${NC}"
echo "📊 Size: $(du -h "$DMG_NAME" | cut -f1)"
echo "🔐 SHA256: $(cat "${DMG_NAME}.sha256" | cut -d' ' -f1)"
echo ""
echo "To create a release:"
echo "1. git tag -a v${VERSION} -m 'Release v${VERSION}'"
echo "2. git push origin v${VERSION}"
echo "3. The GitHub Action will automatically create the release"