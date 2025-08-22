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

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var appState = AppState()
    var bt: Bt!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("[NoQCNoLife] Application starting...")
        
        // Create the menu bar icon FIRST
        createStatusBarItem()
        
        // Initialize Bluetooth
        bt = Bt(self)
        
        NSLog("[NoQCNoLife] Application initialization complete")
    }
    
    func createStatusBarItem() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up the button
        if let button = statusItem.button {
            button.title = "QC"
            button.toolTip = "NoQCNoLife - Bose QC Controller"
            NSLog("[NoQCNoLife] Menu bar button created with title 'QC'")
        }
        
        // Create menu
        menu = NSMenu()
        
        // Add menu items
        menu.addItem(NSMenuItem(title: "Connect to Device", action: #selector(connectDevice), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let ncMenu = NSMenu()
        ncMenu.addItem(NSMenuItem(title: "High", action: #selector(setNCHigh), keyEquivalent: ""))
        ncMenu.addItem(NSMenuItem(title: "Low", action: #selector(setNCLow), keyEquivalent: ""))
        ncMenu.addItem(NSMenuItem(title: "Off", action: #selector(setNCOff), keyEquivalent: ""))
        
        let ncItem = NSMenuItem(title: "Noise Cancellation", action: nil, keyEquivalent: "")
        ncItem.submenu = ncMenu
        menu.addItem(ncItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Debug Window", action: #selector(showDebugWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Connections", action: #selector(showConnections), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // Assign menu to status item
        statusItem.menu = menu
        
        NSLog("[NoQCNoLife] Menu bar setup complete")
    }
    
    @objc func connectDevice() {
        NSLog("[NoQCNoLife] Connect device requested")
        bt?.checkForConnectedDevices()
    }
    
    @objc func setNCHigh() {
        NSLog("[NoQCNoLife] Setting NC to High")
        _ = bt?.sendSetGetAnrModePacket(.HIGH)
    }
    
    @objc func setNCLow() {
        NSLog("[NoQCNoLife] Setting NC to Low")
        _ = bt?.sendSetGetAnrModePacket(.LOW)
    }
    
    @objc func setNCOff() {
        NSLog("[NoQCNoLife] Setting NC to Off")
        _ = bt?.sendSetGetAnrModePacket(.OFF)
    }
    
    @objc func showDebugWindow() {
        DebugWindowController.shared.showWindow()
    }
    
    @objc func showConnections() {
        ConnectionsWindowController.shared.showWindow()
    }
    
    func updateMenuBarIcon(for mode: Bose.AnrMode?) {
        guard let button = statusItem.button else { return }
        
        // Update the title based on NC mode
        switch mode {
        case .HIGH: button.title = "QC-H"
        case .LOW: button.title = "QC-L"
        case .OFF: button.title = "QC-O"
        case .WIND: button.title = "QC-W"
        case nil: button.title = "QC"
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        bt?.closeConnection()
    }
}

// MARK: - BluetoothDelegate, DeviceManagementEventHandler
extension AppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    nonisolated func onConnect() {
        Task { @MainActor in
            NSLog("[NoQCNoLife] Device connected")
            appState.isConnected = true
            
            // Request initial status
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                _ = self?.bt.sendGetBatteryLevelPacket()
                _ = self?.bt.sendGetAnrModePacket()
            }
        }
    }
    
    nonisolated func onDisconnect() {
        Task { @MainActor in
            NSLog("[NoQCNoLife] Device disconnected")
            appState.isConnected = false
            updateMenuBarIcon(for: nil)
        }
    }
    
    nonisolated func bassControlStepChanged(_ step: Int?) {
        Task { @MainActor in
            NSLog("[NoQCNoLife] Bass control: \(step?.description ?? "nil")")
            appState.bassControlStep = step
        }
    }
    
    nonisolated func batteryLevelStatus(_ level: Int?) {
        Task { @MainActor in
            NSLog("[NoQCNoLife] Battery level: \(level?.description ?? "nil")%")
            appState.batteryLevel = level
        }
    }
    
    nonisolated func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        Task { @MainActor in
            NSLog("[NoQCNoLife] NC mode: \(mode?.toString() ?? "nil")")
            appState.noiseCancelMode = mode
            updateMenuBarIcon(for: mode)
        }
    }
    
    nonisolated func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        Task { @MainActor in
            NSLog("[NoQCNoLife] Received \(devices.count) paired devices")
            ConnectionsManager.shared.didReceiveDeviceList(devices)
        }
    }
    
    nonisolated func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        Task { @MainActor in
            NSLog("[NoQCNoLife] Device info received for \(deviceInfo.macAddress)")
            ConnectionsManager.shared.onDeviceInfoReceived(deviceInfo)
        }
    }
}