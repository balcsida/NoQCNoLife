/*
 Copyright (C) 2025 NoQCNoLife Contributors
 
 This file is part of 'No QC, No Life'.
 
 'No QC, No Life' is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 1, or (at your option)
 any later version.
 
 'No QC, No Life' is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

import Cocoa
import SwiftUI
import IOBluetooth

@MainActor
class SwiftUIAppDelegate: NSObject, ObservableObject {
    
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var bt: Bt?
    var connectionManager: ConnectionsManager?
    var appState: AppState = AppState()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize Bluetooth
        bt = Bt()
        connectionManager = ConnectionsManager()
        
        // Set up popover with SwiftUI content
        setupPopover()
    }
    
    func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MainContentView()
                .environmentObject(appState)
                .environmentObject(self)
        )
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        bt?.disconnect()
    }
    
    func userSelectedNoiseCancelMode(_ mode: Bose.AnrMode) {
        bt?.noiseCancelMode = mode
        appState.noiseCancelMode = mode
    }
    
    func userSelectedBassControlStep(_ step: Int) {
        bt?.bassControlStep = step
        appState.bassControlStep = step
    }
}

// Extension for Bluetooth delegate methods
extension SwiftUIAppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    nonisolated func onConnect() {
        Task { @MainActor in
            appState.isConnected = true
        }
    }
    
    nonisolated func onDisconnect() {
        Task { @MainActor in
            appState.isConnected = false
            appState.connectedProduct = nil
            appState.batteryLevel = nil
            appState.noiseCancelMode = nil
            appState.bassControlStep = nil
        }
    }
    
    nonisolated func bassControlStepChanged(_ step: Int?) {
        Task { @MainActor in
            appState.bassControlStep = step
        }
    }
    
    nonisolated func batteryLevelStatus(_ level: Int?) {
        Task { @MainActor in
            appState.batteryLevel = level
        }
    }
    
    nonisolated func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        Task { @MainActor in
            appState.noiseCancelMode = mode
        }
    }
    
    nonisolated func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        Task { @MainActor in
            // Handle device list update
        }
    }
    
    nonisolated func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        Task { @MainActor in
            // Handle device info update
            if let productId = deviceInfo.productId {
                appState.connectedProduct = Bose.Products(rawValue: productId)
            }
        }
    }
}