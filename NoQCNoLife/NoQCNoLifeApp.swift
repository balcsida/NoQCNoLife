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
import os.log

@MainActor
class BluetoothManager {
    static let shared = BluetoothManager()
    var bt: Bt?
    
    private init() {}
    
    func setBluetooth(_ bluetooth: Bt) {
        self.bt = bluetooth
    }
}

// This struct is no longer needed as we're using AppDelegate with @main
// The SwiftUI integration is handled through SwiftUIAppDelegate below

@MainActor
class SwiftUIAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    @Published var appState = AppState()
    var bt: Bt!
    private var connectBtUserNotification: IOBluetoothUserNotification!
    private var statusUpdateTimer: Timer?
    private var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("[SwiftUIAppDelegate]: applicationDidFinishLaunching called")
        NSLog("[NoQCNoLife]: SwiftUI Application did finish launching")
        
        // Status bar item is already created by AppDelegate
        // Just set up the popover
        setupPopover()
        
        // Initialize Bluetooth
        print("[SwiftUIAppDelegate]: Initializing Bluetooth")
        DebugWindowController.shared.addLog("[NoQCNoLife]: SwiftUI Application did finish launching")
        bt = Bt(self)
        BluetoothManager.shared.setBluetooth(bt)
        connectBtUserNotification = IOBluetoothDevice.register(forConnectNotifications: bt,
                                                               selector: #selector(bt.onNewConnectionDetected))
        
        NSLog("[NoQCNoLife]: Registered for Bluetooth notifications")
        DebugWindowController.shared.addLog("[NoQCNoLife]: Registered for Bluetooth notifications")
        
        // Set up event monitor to close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(event)
            }
        }
        
        // Check for connected devices after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            NSLog("[NoQCNoLife]: Checking for connected devices on startup")
            DebugWindowController.shared.addLog("[NoQCNoLife]: Checking for connected devices on startup")
            self?.bt.checkForConnectedDevices()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
        connectBtUserNotification?.unregister()
        bt?.closeConnection()
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func setupPopover() {
        print("[setupPopover]: Starting setup")
        NSLog("[NoQCNoLife]: Setting up popover")
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.animates = false
        
        let contentView = MainContentView()
            .environmentObject(appState)
            .environmentObject(self)
        
        popover.contentViewController = NSHostingController(rootView: contentView)
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    func updateStatusBarIcon(for mode: Bose.AnrMode?) {
        guard let button = statusItem.button else { return }
        
        let symbol: SFSymbol
        if mode == nil {
            symbol = .waveformCircle
        } else {
            switch mode! {
            case .HIGH: symbol = .waveformCircleFill
            case .LOW: symbol = .waveformCircle
            case .OFF: symbol = .waveform
            case .WIND: symbol = .waveformPath
            }
        }
        
        let icon = NSImage(systemSymbol: symbol, accessibilityDescription: "NoQCNoLife")
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = true  // This makes the icon adapt to light/dark mode
        button.image = icon
        button.needsDisplay = true
    }
    
    // User action handlers
    func userSelectedNoiseCancelMode(_ mode: Bose.AnrMode) {
        NSLog("[NoQCNoLife]: User selected noise cancel mode: \(mode.toString())")
        if !bt.sendSetGetAnrModePacket(mode) {
            appState.updateNoiseCancelMode(nil)
        }
    }
    
    func userSelectedBassControlStep(_ step: Int) {
        NSLog("[NoQCNoLife]: User selected bass control step: \(step)")
        if !bt.sendSetGetBassControlPacket(step) {
            appState.updateBassControlStep(nil)
        }
    }
}

// MARK: - BluetoothDelegate, DeviceManagementEventHandler

extension SwiftUIAppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    nonisolated func onConnect() {
        Task { @MainActor in
        NSLog("[NoQCNoLife]: onConnect() called")
        guard let product = Bose.Products.getById(self.bt.getProductId()) else {
            NSLog("[NoQCNoLife]: ERROR - Invalid product id in onConnect()")
            return
        }
        NSLog("[NoQCNoLife]: Connected to \(product.getName())")
        DebugWindowController.shared.addLog("[NoQCNoLife]: Connected to \(product.getName())")
        
        appState.connected(to: product)
        
        // Request battery level and noise cancellation mode after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            NSLog("[NoQCNoLife]: Requesting initial battery level and ANR mode")
            DebugWindowController.shared.addLog("[NoQCNoLife]: Requesting initial battery level and ANR mode")
            
            _ = self.bt.sendGetBatteryLevelPacket()
            _ = self.bt.sendGetAnrModePacket()
        }
        }
    }
    
    nonisolated func onDisconnect() {
        Task { @MainActor in
            NSLog("[NoQCNoLife]: Disconnected")
            statusUpdateTimer?.invalidate()
            statusUpdateTimer = nil
            appState.disconnected()
            updateStatusBarIcon(for: nil)
        }
    }
    
    nonisolated func bassControlStepChanged(_ step: Int?) {
        Task { @MainActor in
            NSLog("[NoQCNoLife]: Bass control step changed: \(step?.description ?? "nil")")
            appState.updateBassControlStep(step)
        }
    }
    
    nonisolated func batteryLevelStatus(_ level: Int?) {
        Task { @MainActor in
            NSLog("[NoQCNoLife]: Battery level: \(level?.description ?? "nil")")
            appState.updateBatteryLevel(level)
        }
    }
    
    nonisolated func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        Task { @MainActor in
            NSLog("[NoQCNoLife]: Noise cancel mode changed: \(mode?.toString() ?? "nil")")
            appState.updateNoiseCancelMode(mode)
            updateStatusBarIcon(for: mode)
            
            if let mode = mode, let product = Bose.Products.getById(self.bt.getProductId()) {
                PreferenceManager.setLastSelectedAnrMode(product: product, anrMode: mode)
            }
        }
    }
    
    // MARK: - DeviceManagementEventHandler
    
    nonisolated func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        Task { @MainActor in
            NSLog("[NoQCNoLife]: Received device list with \(devices.count) devices")
            ConnectionsManager.shared.didReceiveDeviceList(devices)
        }
    }
    
    nonisolated func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        Task { @MainActor in
            NSLog("[NoQCNoLife]: Received device info for \(deviceInfo.macAddress)")
            ConnectionsManager.shared.onDeviceInfoReceived(deviceInfo)
        }
    }
}

