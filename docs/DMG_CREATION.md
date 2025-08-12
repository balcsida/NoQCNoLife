# DMG Creation

NoQCNoLife uses [sindresorhus/create-dmg](https://github.com/sindresorhus/create-dmg) to create professional-looking DMG files for distribution.

## Benefits of create-dmg

- **Professional appearance**: Creates beautiful DMG files with proper layout
- **Drag-and-drop installation**: Visual indication of dragging app to Applications
- **Automatic optimization**: Compresses and optimizes the DMG size
- **Consistent experience**: Same look across all releases
- **No manual configuration**: Works out of the box

## Local DMG Creation

### Prerequisites

The script will automatically install `create-dmg` if not present. You can also install it manually:

```bash
# Via npm (recommended)
npm install -g create-dmg

# Or via Homebrew
brew install create-dmg
```

### Creating a DMG

```bash
# Create DMG with current version from Info.plist
./scripts/create-dmg.sh

# Or specify a version
./scripts/create-dmg.sh 1.4.0
```

The script will:
1. Build the app in Release configuration
2. Create a professional DMG with:
   - The app positioned on the left
   - Applications folder alias on the right
   - Drag-and-drop visual hint
   - Optimized compression
3. Calculate SHA256 checksum
4. Display the result

## GitHub Actions

The release workflow automatically creates DMGs using create-dmg when you push a version tag:

```bash
git tag -a v1.4.0 -m "Release v1.4.0"
git push origin v1.4.0
```

## DMG Layout

The DMG window appears with:
- **Window size**: 600x400 pixels
- **App icon**: Positioned on the left (150, 185)
- **Applications folder**: Positioned on the right (450, 185)
- **Icon size**: 100x100 pixels
- **Drag hint**: Visual arrow showing drag direction

## Fallback

If create-dmg fails for any reason, the scripts fall back to using `hdiutil` to create a basic DMG. This ensures releases are never blocked.

## Troubleshooting

### create-dmg not found
- Run `npm install -g create-dmg`
- Or use Homebrew: `brew install create-dmg`

### DMG creation fails
- Check that the app builds successfully first
- Ensure you have enough disk space
- The script will fall back to basic DMG creation

### Custom background image
To add a custom background image in the future:
1. Create a 600x400 pixel image
2. Save as `dmg-background.png` in the project root
3. Add `--background dmg-background.png` to the create-dmg command