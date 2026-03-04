# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NoQCNoLife is a macOS menu bar app for controlling Bose QuietComfort headphones. It communicates with Bose devices over Bluetooth RFCOMM using the proprietary BMAP (Bose Music Application Protocol) binary protocol. Supported devices: QC35, QC35 Series II, SoundWear Companion.

## Build Commands

```bash
# Build
xcodebuild -project NoQCNoLife.xcodeproj -scheme NoQCNoLife -configuration Debug build

# Clean
xcodebuild -project NoQCNoLife.xcodeproj -scheme NoQCNoLife clean

# Run (after build)
open ~/Library/Developer/Xcode/DerivedData/NoQCNoLife-*/Build/Products/Debug/NoQCNoLife.app
```

Requirements: Xcode 15+, Swift 6, macOS 11.0+ deployment target. No external dependencies — only system frameworks (IOBluetooth, Cocoa, SwiftUI).

## Architecture

### App Entry & UI Layer

- **`AppDelegate.swift`** — `@main` entry point. Sets up the `NSStatusItem` (menu bar icon) and an `NSPopover` hosting SwiftUI views. Also implements `BluetoothDelegate` to bridge Bluetooth events into `AppState`. Owns the `Bt` instance.
- **`AppState.swift`** — `ObservableObject` holding all UI-bound state: connection status, battery level, noise cancellation mode, bass control step, connected product type. Injected as `@EnvironmentObject` into SwiftUI views.
- **`MainContentView.swift`** — Root SwiftUI view shown in the popover. Contains header, noise cancellation controls, bass control slider, and footer with Connections/Debug/Quit buttons.
- **`ConnectionsView.swift`** / **`ConnectionsWindowController.swift`** — Manage paired device list UI (separate NSWindow, not the popover).
- **`DebugWindowController.swift`** — Debug output window.
- **`SwiftUIAppDelegate.swift`** — Dead file (contains only a removal notice). Can be deleted.

### Bluetooth Layer

- **`Bt.swift`** — Core Bluetooth class. Manages IOBluetooth RFCOMM channel lifecycle: device discovery, connection, packet send/receive, disconnect handling. Uses `ConnectionState` (thread-safe wrapper with GCD barrier queue) for channel/device state. Implements `IOBluetoothRFCOMMChannelDelegate`.
- **`BluetoothManager`** (in `NoQCNoLifeApp.swift`) — Singleton providing global access to the `Bt` instance. Set once during app launch.

### BMAP Protocol Layer (`bose/`)

The app communicates with Bose devices using BMAP — a binary packet protocol over Bluetooth RFCOMM.

- **`BmapPacket.swift`** — Binary packet parser/builder. Each packet has: function block ID, function ID, operator ID, device ID, port, and payload. Fields use single-letter names (`a`–`g`) matching the decompiled Android source this was reverse-engineered from.
- **`Bose.swift`** — Top-level protocol facade. Contains `Products` enum (device identification by product ID), `AnrMode` enum (noise cancellation modes), supported product check, and packet generation convenience methods.
- **`EventHandler.swift`** — Defines `EventHandler` and `DeviceManagementEventHandler` protocols for receiving parsed BMAP events. Also defines `BosePairedDevice` and `DeviceInfo` data structs.

### Function Blocks (`bose/FunctionBlocks/`)

Each function block handles a category of BMAP operations, following the Bose firmware's function block architecture:

- **`FunctionBlock.swift`** — `FunctionBlock` protocol and `FunctionBlockFactory` (maps function block IDs to implementations).
- **`ProductInfoFunctionBlock.swift`** — BMAP version negotiation (must be sent first after RFCOMM channel opens, or the device sends no data).
- **`SettingsFunctionBlock.swift`** — Noise cancellation (ANR) mode and bass control get/set.
- **`StatusFunctionBlock.swift`** — Battery level queries.
- **`DeviceManagementFunctionBlock.swift`** — Paired device list, connect/disconnect/remove devices, pairing mode.
- **`AudioManagementFunctionBlock.swift`** — Audio source management.

### Other Key Files

- **`ConnectionsManager.swift`** — Singleton `ObservableObject` managing paired device operations (refresh, connect, disconnect, remove, pairing mode toggle).
- **`PreferenceManager.swift`** — Persists last-selected ANR mode per product via `UserDefaults`.

## Key Architectural Notes

- **BMAP handshake is critical**: After opening the RFCOMM channel, a BMAP version packet must be sent before the device will respond to any other commands. This is handled in `Bt.sendBmapVersionPacket()`.
- **Thread safety**: `Bt` uses `ConnectionState` with a GCD concurrent queue + barrier writes. UI updates from Bluetooth callbacks use `Task { @MainActor in ... }`.
- **Product identification**: Devices are identified by PnP vendor ID (158 = Bose) + product ID from SDP service records. Only 3 products are currently enabled in `Bose.Products`.
- **Concurrency model**: Swift 6 strict concurrency. `Bt` is `@unchecked Sendable` with manual thread safety. `AppDelegate` and `AppState` are `@MainActor`.
