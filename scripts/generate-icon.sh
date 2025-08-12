#!/bin/bash

# Script to generate app icon and button image from Bose logo SVG
# Uses the official Bose logo glyph (unicode="&#xeb51;")

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo -e "${YELLOW}ImageMagick is not installed. Installing via Homebrew...${NC}"
    brew install imagemagick
fi

# Use magick if available (ImageMagick 7), otherwise fall back to convert
if command -v magick &> /dev/null; then
    CONVERT_CMD="magick"
else
    CONVERT_CMD="convert"
fi

# Check if librsvg is installed (for better SVG rendering)
if ! command -v rsvg-convert &> /dev/null; then
    echo -e "${YELLOW}librsvg is not installed. Installing via Homebrew...${NC}"
    brew install librsvg
fi

echo "Generating app icons from Bose logo SVG..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Working in $TEMP_DIR"

# Convert main icon SVG to high-resolution PNG using rsvg-convert for better quality
rsvg-convert -w 1024 -h 1024 assets/icon.svg -o "$TEMP_DIR/icon_1024.png"

# Add white background for better appearance in app icon
$CONVERT_CMD "$TEMP_DIR/icon_1024.png" \
    -background white \
    -gravity center \
    -extent 1024x1024 \
    "$TEMP_DIR/icon_with_bg.png"

# Create iconset directory
ICONSET_DIR="$TEMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Generate all required sizes for macOS app icon
echo "Generating app icon sizes..."

# 16x16
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 16x16 "$ICONSET_DIR/icon_16x16.png"
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 32x32 "$ICONSET_DIR/icon_16x16@2x.png"

# 32x32
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 32x32 "$ICONSET_DIR/icon_32x32.png"
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 64x64 "$ICONSET_DIR/icon_32x32@2x.png"

# 128x128
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 128x128 "$ICONSET_DIR/icon_128x128.png"
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 256x256 "$ICONSET_DIR/icon_128x128@2x.png"

# 256x256
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 256x256 "$ICONSET_DIR/icon_256x256.png"
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 512x512 "$ICONSET_DIR/icon_256x256@2x.png"

# 512x512
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 512x512 "$ICONSET_DIR/icon_512x512.png"
$CONVERT_CMD "$TEMP_DIR/icon_with_bg.png" -resize 1024x1024 "$ICONSET_DIR/icon_512x512@2x.png"

# Check if oxipng is installed
if ! command -v oxipng &> /dev/null; then
    echo -e "${YELLOW}oxipng is not installed. Installing via Homebrew...${NC}"
    brew install oxipng
fi

# Optimize PNG files with oxipng and zopfli
echo "Optimizing PNG files with oxipng (using zopfli)..."
for png in "$ICONSET_DIR"/*.png; do
    oxipng -o max --zopfli --strip safe "$png" &
done
wait # Wait for all background jobs to complete

# Generate ICNS file for the app bundle
echo "Creating ICNS file..."
iconutil -c icns "$ICONSET_DIR" -o NoQCNoLife/AppIcon.icns

# Copy PNG files to AppIcon.appiconset for Asset Catalog
APPICON_DIR="NoQCNoLife/Assets.xcassets/AppIcon.appiconset"
echo "Copying optimized PNG files to Asset Catalog..."
cp "$ICONSET_DIR/icon_16x16.png" "$APPICON_DIR/icon_16.png"
cp "$ICONSET_DIR/icon_32x32.png" "$APPICON_DIR/icon_32.png"
cp "$ICONSET_DIR/icon_32x32@2x.png" "$APPICON_DIR/icon_64.png"
cp "$ICONSET_DIR/icon_128x128.png" "$APPICON_DIR/icon_128.png"
cp "$ICONSET_DIR/icon_128x128@2x.png" "$APPICON_DIR/icon_256.png"
cp "$ICONSET_DIR/icon_256x256.png" "$APPICON_DIR/icon_256-1.png"
cp "$ICONSET_DIR/icon_256x256@2x.png" "$APPICON_DIR/icon_512.png"
cp "$ICONSET_DIR/icon_512x512.png" "$APPICON_DIR/icon_512-1.png"
cp "$ICONSET_DIR/icon_512x512@2x.png" "$APPICON_DIR/icon_1024.png"

# Generate ButtonImg for menu bar
echo "Setting up ButtonImg SVG for menu bar..."

# Create ButtonImg asset catalog if it doesn't exist
BUTTON_ASSET_DIR="NoQCNoLife/Assets.xcassets/ButtonImg.imageset"
mkdir -p "$BUTTON_ASSET_DIR"

# Copy SVG directly
cp assets/button-icon.svg "$BUTTON_ASSET_DIR/ButtonImg.svg"

# Create Contents.json for ButtonImg to use SVG
cat > "$BUTTON_ASSET_DIR/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "ButtonImg.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
EOF

# Clean up
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Icons generated successfully!${NC}"
echo "Icon files created:"
echo "  - AppIcon.icns (for app icon)"
echo "  - ButtonImg.svg (for menu bar icon)"
echo ""
echo "Note: ButtonImg uses SVG directly for better scalability."
echo "AppIcon still uses ICNS format as required by macOS."