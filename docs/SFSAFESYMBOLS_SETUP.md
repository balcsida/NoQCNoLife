# Adding SFSafeSymbols to NoQCNoLife

SFSafeSymbols provides compile-time safe SF Symbol references for the menu bar icons.

## Setup Instructions

1. Open `NoQCNoLife.xcodeproj` in Xcode

2. Add Swift Package Dependency:
   - Select the project in the navigator
   - Select the NoQCNoLife project (not the target)
   - Go to "Package Dependencies" tab
   - Click the "+" button
   - Enter the repository URL: `https://github.com/SFSafeSymbols/SFSafeSymbols.git`
   - Set version rule to: "Up to Next Major Version" from `6.2.0`
   - Click "Add Package"

3. Add to Target:
   - When prompted, ensure "SFSafeSymbols" is added to the "NoQCNoLife" target
   - Click "Add Package"

## Benefits

- **Compile-time Safety**: Symbol names are checked at compile time
- **Auto-completion**: Xcode provides auto-completion for all available symbols
- **Type Safety**: No more string-based symbol names
- **Cleaner Code**: More readable and maintainable

## Usage

The app now uses SFSafeSymbols for all menu bar icons:
- Device disconnected: `waveformCircle`
- NC High: `waveformCircleFill` 
- NC Low: `waveformCircle`
- NC Off: `waveform`
- Wind Mode: `waveformPath`

## Requirements

- macOS 11.0+ (Big Sur or later)
- Xcode 13.0+
- Swift 5.5+