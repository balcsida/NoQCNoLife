#!/bin/bash

# Build test script for NoQCNoLife
echo "Building NoQCNoLife with all Swift files..."

cd NoQCNoLife

# List of all Swift files to compile
SWIFT_FILES=(
    "AppDelegate.swift"
    "NoQCNoLifeApp.swift"
    "AppState.swift"
    "MainContentView.swift"
    "ConnectionsView.swift"
    "ConnectionsManager.swift"
    "ConnectionsWindowController.swift"
    "DebugWindowController.swift"
    "PreferenceManager.swift"
    "Preferences.swift"
    "Bt.swift"
    "bose/Bose.swift"
    "bose/BmapPacket.swift"
    "bose/EventHandler.swift"
    "bose/FunctionBlocks/FunctionBlock.swift"
    "bose/FunctionBlocks/DeviceManagementFunctionBlock.swift"
    "bose/FunctionBlocks/AudioManagementFunctionBlock.swift"
    "bose/FunctionBlocks/SettingsFunctionBlock.swift"
    "bose/FunctionBlocks/StatusFunctionBlock.swift"
    "bose/FunctionBlocks/ProductInfoFunctionBlock.swift"
)

# Compile with swiftc
swiftc \
    -o ../NoQCNoLife_test \
    -sdk $(xcrun --show-sdk-path) \
    -target arm64-apple-macos12.0 \
    -framework IOBluetooth \
    -framework Cocoa \
    -framework SwiftUI \
    -swift-version 6 \
    "${SWIFT_FILES[@]}"

echo "Build complete!"