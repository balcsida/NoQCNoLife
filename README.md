# No QC, No Life

![Screenshot when QuietComfort 35 II is connected](https://github.com/user-attachments/assets/d0f9c1ae-5379-41c8-b9e3-d3423c211c2a "Screenshot when QuietComfort 35 II is connected")

This application lets you control the **Bose QuietComfort 35** from macOS.  
It lives in your menu bar and allows you to check the battery level and adjust the noise cancellation level.

Originally created by **Shun Ito** (@ll0s0ll) in 2021.

QuietComfort 35 headphones have become indispensable to many users' daily lives.  
While similar functions exist in the smartphone app, this Mac app provides convenient access to headphone controls directly from the menu bar.

The app has been tested on both QuietComfort 35 and QuietComfort 35 Series II.  
Other supported models are listed below.

This is an unofficial project; we have not obtained permission from any of the relevant parties.

## How to Use

1. Launch the application and use your QuietComfort headphones as usual.  
2. The app automatically detects when a supported device connects or disconnects.  
3. For convenience, add the app to your **Login Items** so it launches at startup:  
   **System Preferences ▸ Users & Groups ▸ Login Items** (on macOS 10.13 High Sierra).

## Supported Devices

- Bose QuietComfort 35  
- Bose QuietComfort 35 Series II
- Bose SoundWear Companion

## System Requirements

macOS 11.0 (Big Sur) or later.

**Note:** The app has been migrated to SwiftUI, requiring macOS 11.0 or later for the modern user interface.

## Installation

### Option 1: Homebrew (Recommended)
```bash
brew tap balcsida/noqcnolife https://github.com/balcsida/NoQCNoLife
brew install --cask noqcnolife
```

### Option 2: Direct Download
Download the **.dmg** from the [latest release](https://github.com/balcsida/NoQCNoLife/releases/latest).

## Building from Source

### Requirements
- Xcode 15.0 or later
- Swift 6.1.2 or later
- macOS 11.0 SDK or later

### Build Instructions
1. Clone the repository
2. Open `NoQCNoLife.xcodeproj` in Xcode
3. Update Build Settings:
   - Swift Language Version: Set to "Swift 6" 
   - macOS Deployment Target: 11.0 or later
4. Clean Build Folder (Shift+Cmd+K)
5. Build and run (Cmd+R)

## Credits

**Original Author:** Shun Ito @ll0s0ll (2020-2021)  
**Current Maintainer:** Dávid Balatoni @balcsida (2025)

## Disclaimer

We accept no responsibility for any physical damage, data loss, financial loss, or any other harm resulting from the use of this software.
