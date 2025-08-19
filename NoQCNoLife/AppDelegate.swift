/*
 Copyright (C) 2021 Shun Ito
 
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
import IOBluetooth
import os.log

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var bt: Bt!
    var statusItem: StatusItem!
    var connectBtUserNotification: IOBluetoothUserNotification!
    var statusUpdateTimer: Timer?
    
//    func applicationWillFinishLaunching(_ aNotification: Notification) {
//        print("applicationWillFinishLaunching()")
//    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        NSLog("[NoQCNoLife]: Application did finish launching")
        print("applicationDidFinishLaunching()")
        
        bt = Bt(self)
        connectBtUserNotification = IOBluetoothDevice.register(forConnectNotifications: bt,
                                                               selector:#selector(bt.onNewConnectionDetected))
        
        NSLog("[NoQCNoLife]: Registered for Bluetooth notifications")
        
        // Immediate check to verify Bt is initialized
        NSLog("[NoQCNoLife]: Bt initialized: \(bt != nil)")
        
        // Check for already connected devices after notifications are set up
        NSLog("[NoQCNoLife]: Scheduling delayed check for connected devices...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            NSLog("[NoQCNoLife]: Delayed check timer fired")
            guard let self = self else {
                NSLog("[NoQCNoLife]: ERROR - self is nil in delayed check")
                return
            }
            NSLog("[NoQCNoLife]: Checking for connected devices on startup (delayed by 1 second)")
            #if DEBUG
            print("[AppDelegate]: About to check for connected devices on startup")
            #endif
            self.bt.checkForConnectedDevices()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        self.statusUpdateTimer?.invalidate()
        self.statusUpdateTimer = nil
        connectBtUserNotification?.unregister()
        self.bt?.closeConnection()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.statusItem = StatusItem(self)
    }
}

extension AppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    func onConnect() {
        NSLog("[NoQCNoLife]: onConnect() called")
        guard let product = Bose.Products.getById(self.bt.getProductId()) else {
            NSLog("[NoQCNoLife]: ERROR - Invalid product id in onConnect()")
            // assert(false, "Invalid prodcut id.")
            return
        }
        NSLog("[NoQCNoLife]: Connected to \(product.getName())")
        #if DEBUG
        print("[BT]: Connected to \(product.getName())")
        #endif
        self.statusItem.connected(product)
        
        // Poll for status briefly after connection to ensure we have the correct state
        // The Bose device automatically sends notifications when NC mode changes (from button presses)
        // so we only need initial polling to establish the current state
        var pollCount = 0
        self.statusUpdateTimer?.invalidate()
        self.statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            pollCount += 1
            
            // Request current status
            _ = self.bt.sendGetAnrModePacket()
            
            // Stop polling after 3 attempts (6 seconds total)
            // After this, we rely on the device sending notifications for changes
            if pollCount >= 3 {
                NSLog("[NoQCNoLife]: Stopping initial status polling, device will send notifications for changes")
                timer.invalidate()
                self.statusUpdateTimer = nil
            }
        }
        
        // Don't automatically set ANR mode on connection - it interrupts the device
        // and causes a "boop" sound. Users can manually set it if needed.
        // The device will maintain its last setting anyway.
        /*
        if let lastSelectedAnrMode = PreferenceManager.getLastSelectedAnrMode(product) {
            if (!self.bt.sendSetGetAnrModePacket(lastSelectedAnrMode)) {
                self.noiseCancelModeChanged(nil)
            }
        }
        */
        
        // Request battery level and noise cancellation mode after a short delay
        // This gives the device time to stabilize after connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            NSLog("[NoQCNoLife]: Requesting initial battery level and ANR mode (delayed by 1.5 seconds)")
            
            // Get battery level
            if (!self.bt.sendGetBatteryLevelPacket()) {
                NSLog("[NoQCNoLife]: Failed to send battery level packet")
                self.batteryLevelStatus(nil)
            } else {
                NSLog("[NoQCNoLife]: Successfully sent battery level request")
            }
            
            // Get current noise cancellation mode (just to display, not to set)
            if (!self.bt.sendGetAnrModePacket()) {
                NSLog("[NoQCNoLife]: Failed to send ANR mode packet")
                self.noiseCancelModeChanged(nil)
            } else {
                NSLog("[NoQCNoLife]: Successfully sent ANR mode request")
            }
        }
    }
    
    func onDisconnect() {
        #if DEBUG
        print("[BT]: Disconnected")
        #endif
        // Stop the status update timer when disconnected
        self.statusUpdateTimer?.invalidate()
        self.statusUpdateTimer = nil
        self.statusItem.disconnected()
    }
    
    func bassControlStepChanged(_ step: Int?) {
        #if DEBUG
        print("[BassControlEvent]: \(step != nil ? String(step!) : "nil")")
        #endif
        self.statusItem.setBassControlStep(step)
    }
    
    func batteryLevelStatus(_ level: Int?) {
        #if DEBUG
        print("[BatteryLevelEvent]: \(level != nil ? String(level!) : "nil")")
        #endif
        self.statusItem.setBatteryLevel(level)
    }
    
    func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        NSLog("[NoQCNoLife]: noiseCancelModeChanged called with mode: \(mode?.toString() ?? "nil")")
        #if DEBUG
        print("[AnrModeEvent]: \(mode?.toString() ?? "nil")")
        #endif
        
        // Always update the UI, even if mode is nil
        self.statusItem.setNoiseCancelMode(mode)
        
        if (mode != nil) {
            if let product = Bose.Products.getById(self.bt.getProductId()) {
                PreferenceManager.setLastSelectedAnrMode(product: product, anrMode: mode!)
            }
        }
    }
    
    // MARK: - DeviceManagementEventHandler
    
    func onDeviceListReceived(_ devices: [BoseConnectedDevice]) {
        // Forward the device list to the connections window if it's open
        ConnectionsWindowController.shared.didReceiveDeviceList(devices)
    }
}

extension AppDelegate: StatusItemDelegate {
    
    func bassControlStepSelected(_ step: Int) {
        if (!self.bt.sendSetGetBassControlPacket(step)) {
            self.noiseCancelModeChanged(nil)
        }
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        NSLog("[NoQCNoLife]: Menu will open, checking connection")
        NSLog("[NoQCNoLife]: Current product ID: \(self.bt.getProductId() ?? 0)")
        
        #if DEBUG
        print("[AppDelegate]: Menu will open, checking connection")
        print("[AppDelegate]: Current product ID: \(self.bt.getProductId() ?? 0)")
        #endif
        
        // If we have a product ID but the UI doesn't show it, update the UI
        if let productId = self.bt.getProductId(), productId > 0 {
            if !self.statusItem.isConnected() {
                NSLog("[NoQCNoLife]: Device connected but UI not updated, forcing update")
                if let product = Bose.Products.getById(productId) {
                    self.statusItem.connected(product)
                }
            }
        }
        
        // Always try to check for connected devices when menu opens
        self.bt.checkForConnectedDevices()
        
        // Update menu items after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.updateMenuItems(menu)
        }
    }
    
    private func updateMenuItems(_ menu: NSMenu) {
        for menuItem in menu.items {
            switch menuItem.tag {
            case StatusItem.MenuItemTags.BATTERY_LEVEL.rawValue:
                if (!self.bt.sendGetBatteryLevelPacket()) {
                    self.batteryLevelStatus(nil)
                }
            case StatusItem.MenuItemTags.BASS_CONTROL.rawValue:
                if (!self.bt.sendGetBassControlPacket()) {
                    self.bassControlStepChanged(nil)
                }
            case StatusItem.MenuItemTags.NOISE_CANCEL_MODE.rawValue:
                if (!self.bt.sendGetAnrModePacket()) {
                    self.noiseCancelModeChanged(nil)
                }
            default: break
            }
        }
    }
    
    func noiseCancelModeSelected(_ mode: Bose.AnrMode) {
        if (!self.bt.sendSetGetAnrModePacket(mode)) {
            self.noiseCancelModeChanged(nil)
        }
    }
}
