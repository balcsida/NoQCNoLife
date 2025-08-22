# NoQCNoLife Project Instructions

## Project Overview
NoQCNoLife is a macOS application for managing Bose QC headphones, providing noise cancellation control and device management through a menu bar interface.

## Build and Test Commands

### Building
```bash
# Build the project
xcodebuild -project NoQCNoLife.xcodeproj -scheme NoQCNoLife -configuration Debug build

# Clean build
xcodebuild -project NoQCNoLife.xcodeproj -scheme NoQCNoLife clean
```

### Running
```bash
# Run the built app
open /Users/hu901131/Library/Developer/Xcode/DerivedData/NoQCNoLife-*/Build/Products/Debug/NoQCNoLife.app

# Or run directly
/Users/hu901131/Library/Developer/Xcode/DerivedData/NoQCNoLife-*/Build/Products/Debug/NoQCNoLife.app/Contents/MacOS/NoQCNoLife
```

### Testing
```bash
# Run tests
xcodebuild -project NoQCNoLife.xcodeproj -scheme NoQCNoLife test
```

## Code Style Guidelines

### Swift Conventions
- Use 4 spaces for indentation
- Follow Swift API Design Guidelines
- Use descriptive variable and function names
- Prefer `let` over `var` when possible
- Use trailing closure syntax when appropriate

### File Organization
- `/NoQCNoLife/` - Main application code
- `/NoQCNoLife/bose/` - Bose device communication logic
- `/NoQCNoLife/bose/FunctionBlocks/` - Bose function block implementations
- UI files use either AppKit (legacy) or SwiftUI (migration in progress)

### Architecture Notes
- Currently migrating from AppKit to SwiftUI (feat/swiftui-migration branch)
- ConnectionsManager handles Bluetooth device management
- EventHandler processes Bose device events
- FunctionBlocks implement specific Bose device features

## Important Files
- `NoQCNoLife.xcodeproj` - Xcode project file
- `Info.plist` - Application configuration
- `AppDelegate.swift` - Main application delegate
- `ConnectionsManager.swift` - Bluetooth connection management
- `Bt.swift` - Core Bluetooth functionality

## Development Workflow

### Before Making Changes
1. Ensure you're on the correct branch (currently feat/swiftui-migration)
2. Pull latest changes if working collaboratively
3. Check build status with `xcodebuild`

### After Making Changes
1. Test locally by building and running the app
2. Verify Bluetooth functionality if modified
3. Check for any new compiler warnings
4. Commit changes following atomic commit practices

## Debugging
- Use Console.app to view system logs for Bluetooth issues
- Debug output can be viewed in DebugWindowController
- Check Bluetooth permissions in System Settings > Privacy & Security

## Known Issues
- SwiftUI migration is in progress - some UI components may be transitioning
- Bluetooth connection may require system permissions on first run

## Dependencies
- macOS 10.15+ (for SwiftUI support)
- Xcode 12+ for building
- No external package dependencies (uses system frameworks only)