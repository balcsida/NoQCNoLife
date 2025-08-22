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
import SFSafeSymbols

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var swiftUIDelegate: SwiftUIAppDelegate!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Write debug log
        let logPath = "/tmp/noqcnolife_launch.txt"
        try? "AppDelegate launched at \(Date())\n".write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Set as menu bar app - this must be done before creating status item
        NSApp.setActivationPolicy(.accessory)
        
        // Create status item with explicit length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // Set both image and alternate image for better visibility
            let icon = NSImage(systemSymbol: .waveformCircle, accessibilityDescription: "NoQCNoLife")
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = true  // This makes the icon adapt to light/dark mode
            
            button.image = icon
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Add tooltip for better user experience
            button.toolTip = "NoQCNoLife - Click to open"
            
            let existingLog = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
            try? (existingLog + "Status bar created with image\n").write(toFile: logPath, atomically: false, encoding: .utf8)
        }
        
        // Force the status item to be visible
        statusItem.isVisible = true
        
        // Initialize SwiftUI delegate
        swiftUIDelegate = SwiftUIAppDelegate()
        swiftUIDelegate.statusItem = statusItem  // Pass the status item
        swiftUIDelegate.applicationDidFinishLaunching(aNotification)
    }
    
    @objc func statusBarButtonClicked(_ sender: AnyObject?) {
        if swiftUIDelegate.popover == nil {
            swiftUIDelegate.setupPopover()
        }
        swiftUIDelegate.togglePopover(sender)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        swiftUIDelegate?.applicationWillTerminate(aNotification)
    }
}

// Extension to make AppDelegate conform to the protocols needed by Bt
extension AppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    nonisolated func onConnect() {
        Task { @MainActor in
            swiftUIDelegate?.onConnect()
        }
    }
    
    nonisolated func onDisconnect() {
        Task { @MainActor in
            swiftUIDelegate?.onDisconnect()
        }
    }
    
    nonisolated func bassControlStepChanged(_ step: Int?) {
        Task { @MainActor in
            swiftUIDelegate?.bassControlStepChanged(step)
        }
    }
    
    nonisolated func batteryLevelStatus(_ level: Int?) {
        Task { @MainActor in
            swiftUIDelegate?.batteryLevelStatus(level)
        }
    }
    
    nonisolated func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        Task { @MainActor in
            swiftUIDelegate?.noiseCancelModeChanged(mode)
        }
    }
    
    nonisolated func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        Task { @MainActor in
            swiftUIDelegate?.onDeviceListReceived(devices)
        }
    }
    
    nonisolated func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        Task { @MainActor in
            swiftUIDelegate?.onDeviceInfoReceived(deviceInfo)
        }
    }
}