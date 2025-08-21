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

import SwiftUI

@available(macOS 11.0, *)
@main
struct NoQCNoLifeApp: App {
    @NSApplicationDelegateAdaptor(SwiftUIAppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@available(macOS 11.0, *)
class SwiftUIAppDelegate: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var appState = AppState()
    private var bt: Bt!
    private var statusUpdateTimer: Timer?
    private var connectionsViewModel: ConnectionsViewModel!
    
    func setBluetoothInstance(_ bt: Bt) {
        self.bt = bt
        
        // Set up app state delegate
        appState.delegate = self
        
        // Set up connections view model
        connectionsViewModel = ConnectionsViewModel()
        
        // Create status bar item
        setupStatusBarItem()
        
        NSLog("[NoQCNoLife]: SwiftUI delegate initialized")
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use SF Symbol with SFSafeSymbols
            let image = NSImage(systemSymbol: .waveformCircle)
            button.image = image
        }
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: 
            ContentView()
                .environmentObject(appState)
        )
        
        // Set up status item action
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.target = self
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    private func updateStatusBarIcon(for mode: Bose.AnrMode?) {
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
        
        let image = NSImage(systemSymbol: symbol)
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        button.image = image.withSymbolConfiguration(symbolConfig) ?? image
        button.needsDisplay = true
    }
}

// MARK: - BluetoothDelegate, DeviceManagementEventHandler

@available(macOS 11.0, *)
extension SwiftUIAppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    func onConnect() {
        NSLog("[NoQCNoLife]: onConnect() called")
        guard let product = Bose.Products.getById(self.bt.getProductId()) else {
            NSLog("[NoQCNoLife]: ERROR - Invalid product id in onConnect()")
            return
        }
        NSLog("[NoQCNoLife]: Connected to \(product.getName())")
        
        appState.connected(to: product)
        
        // Poll for status briefly after connection
        var pollCount = 0
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            pollCount += 1
            _ = self.bt.sendGetAnrModePacket()
            
            if pollCount >= 3 {
                NSLog("[NoQCNoLife]: Stopping initial status polling")
                timer.invalidate()
                self.statusUpdateTimer = nil
            }
        }
        
        // Request battery level and noise cancellation mode after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            NSLog("[NoQCNoLife]: Requesting initial battery level and ANR mode")
            
            if !self.bt.sendGetBatteryLevelPacket() {
                NSLog("[NoQCNoLife]: Failed to send battery level packet")
                self.batteryLevelStatus(nil)
            }
            
            if !self.bt.sendGetAnrModePacket() {
                NSLog("[NoQCNoLife]: Failed to send ANR mode packet")
                self.noiseCancelModeChanged(nil)
            }
        }
    }
    
    func onDisconnect() {
        NSLog("[NoQCNoLife]: Disconnected")
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
        appState.disconnected()
        updateStatusBarIcon(for: nil)
    }
    
    func bassControlStepChanged(_ step: Int?) {
        NSLog("[NoQCNoLife]: Bass control step changed: \(step?.description ?? "nil")")
        appState.setBassControlStep(step)
    }
    
    func batteryLevelStatus(_ level: Int?) {
        NSLog("[NoQCNoLife]: Battery level: \(level?.description ?? "nil")")
        appState.setBatteryLevel(level)
    }
    
    func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        NSLog("[NoQCNoLife]: Noise cancel mode changed: \(mode?.toString() ?? "nil")")
        appState.setNoiseCancelMode(mode)
        updateStatusBarIcon(for: mode)
        
        if let mode = mode, let product = Bose.Products.getById(self.bt.getProductId()) {
            PreferenceManager.setLastSelectedAnrMode(product: product, anrMode: mode)
        }
    }
    
    // MARK: - DeviceManagementEventHandler
    
    func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        connectionsViewModel?.didReceiveDeviceList(devices)
        SwiftUIConnectionsWindowController.shared.didReceiveDeviceList(devices)
    }
    
    func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        connectionsViewModel?.onDeviceInfoReceived(deviceInfo)
        SwiftUIConnectionsWindowController.shared.onDeviceInfoReceived(deviceInfo)
    }
}

// MARK: - AppStateDelegate

@available(macOS 11.0, *)
extension SwiftUIAppDelegate: AppStateDelegate {
    
    func bassControlStepSelected(_ step: Int) {
        if !bt.sendSetGetBassControlPacket(step) {
            bassControlStepChanged(nil)
        }
    }
    
    func noiseCancelModeSelected(_ mode: Bose.AnrMode) {
        if !bt.sendSetGetAnrModePacket(mode) {
            noiseCancelModeChanged(nil)
        }
    }
}

import SFSafeSymbols