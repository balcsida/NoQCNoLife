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
import SwiftUI
import SFSafeSymbols
import Combine

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var bt: Bt!
    var statusItem: StatusItem!
    var connectBtUserNotification: IOBluetoothUserNotification!
    var statusUpdateTimer: Timer?
    
    // SwiftUI support
    @available(macOS 11.0, *)
    private lazy var swiftUIDelegate: SwiftUIAppDelegate = {
        let delegate = SwiftUIAppDelegate()
        delegate.setBluetoothInstance(bt)
        return delegate
    }()
    
    var useSwiftUI: Bool {
        if #available(macOS 11.0, *) {
            return UserDefaults.standard.bool(forKey: "useSwiftUI")
        }
        return false
    }
    
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
        
        // Initialize UI based on preference
        if #available(macOS 11.0, *), useSwiftUI {
            NSLog("[NoQCNoLife]: Initializing SwiftUI interface")
            _ = swiftUIDelegate // Initialize lazy property
        } else {
            NSLog("[NoQCNoLife]: Initializing AppKit interface")
            // StatusItem will be created in awakeFromNib for AppKit
        }
        
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
        // Only create StatusItem if not using SwiftUI
        if #available(macOS 11.0, *), !useSwiftUI {
            self.statusItem = StatusItem(self)
        } else if !useSwiftUI {
            self.statusItem = StatusItem(self)
        }
    }
}

extension AppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    func onConnect() {
        if #available(macOS 11.0, *), useSwiftUI {
            swiftUIDelegate.onConnect()
            return
        }
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
        if #available(macOS 11.0, *), useSwiftUI {
            swiftUIDelegate.onDisconnect()
            return
        }
        #if DEBUG
        print("[BT]: Disconnected")
        #endif
        // Stop the status update timer when disconnected
        self.statusUpdateTimer?.invalidate()
        self.statusUpdateTimer = nil
        self.statusItem.disconnected()
    }
    
    func bassControlStepChanged(_ step: Int?) {
        if #available(macOS 11.0, *), useSwiftUI {
            swiftUIDelegate.bassControlStepChanged(step)
            return
        }
        #if DEBUG
        print("[BassControlEvent]: \(step != nil ? String(step!) : "nil")")
        #endif
        self.statusItem.setBassControlStep(step)
    }
    
    func batteryLevelStatus(_ level: Int?) {
        if #available(macOS 11.0, *), useSwiftUI {
            swiftUIDelegate.batteryLevelStatus(level)
            return
        }
        #if DEBUG
        print("[BatteryLevelEvent]: \(level != nil ? String(level!) : "nil")")
        #endif
        self.statusItem.setBatteryLevel(level)
    }
    
    func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        if #available(macOS 11.0, *), useSwiftUI {
            swiftUIDelegate.noiseCancelModeChanged(mode)
            return
        }
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
    
    func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        if #available(macOS 11.0, *), useSwiftUI {
            swiftUIDelegate.onDeviceListReceived(devices)
        } else {
            // Forward the device list to the connections window if it's open
            ConnectionsWindowController.shared.didReceiveDeviceList(devices)
        }
    }
    
    func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        if #available(macOS 11.0, *), useSwiftUI {
            swiftUIDelegate.onDeviceInfoReceived(deviceInfo)
        } else {
            // Forward the device info to the connections window if it's open
            ConnectionsWindowController.shared.onDeviceInfoReceived(deviceInfo)
        }
    }
}

extension AppDelegate: StatusItemDelegate {
    
    func bassControlStepSelected(_ step: Int) {
        if (!self.bt.sendSetGetBassControlPacket(step)) {
            self.bassControlStepChanged(nil)
        }
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        NSLog("[NoQCNoLife]: Menu will open, checking connection")
        NSLog("[NoQCNoLife]: Current product ID: \(self.bt.getProductId() ?? 0)")
        
        #if DEBUG
        print("[AppDelegate]: Menu will open, checking connection")
        print("[AppDelegate]: Current product ID: \(self.bt.getProductId() ?? 0)")
        #endif
        
        // Check for Option key and add debug menu item
        let optionKeyPressed = NSEvent.modifierFlags.contains(.option)
        
        // Remove existing debug menu item if it exists
        if let existingDebugItem = menu.items.first(where: { $0.identifier?.rawValue == "debug" }) {
            menu.removeItem(existingDebugItem)
        }
        
        // Add debug menu item if Option is pressed
        if optionKeyPressed {
            let debugMenuItem = NSMenuItem(title: "Debug Console...", action: #selector(openDebugConsole), keyEquivalent: "")
            debugMenuItem.target = self
            debugMenuItem.identifier = NSUserInterfaceItemIdentifier("debug")
            menu.insertItem(debugMenuItem, at: 0)
            menu.insertItem(NSMenuItem.separator(), at: 1)
        }
        
        // If we have a product ID but the UI doesn't show it, update the UI
        if let productId = self.bt.getProductId(), productId > 0 {
            if !self.statusItem.isConnected() {
                NSLog("[NoQCNoLife]: Device connected but UI not updated, forcing update")
                if let product = Bose.Products.getById(productId) {
                    self.statusItem.connected(product)
                }
            }
        }
        
        // Check for connected devices asynchronously to avoid blocking the menu
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.bt.checkForConnectedDevices()
            
            // Update menu items on main thread after device check
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateMenuItems(menu)
            }
        }
    }
    
    @objc private func openDebugConsole() {
        DebugWindowController.shared.showWindow()
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

// MARK: - SwiftUI Support

@available(macOS 11.0, *)
class AppState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectedProduct: Bose.Products?
    @Published var batteryLevel: Int?
    @Published var noiseCancelMode: Bose.AnrMode?
    @Published var bassControlStep: Int?
    
    weak var delegate: AppStateDelegate?
    
    var supportsNoiseCancellation: Bool {
        guard let product = connectedProduct else { return false }
        switch product {
        case .WOLFCASTLE, .BAYWOLF:
            return true
        case .KLEOS:
            return false
        }
    }
    
    var supportsBassControl: Bool {
        guard let product = connectedProduct else { return false }
        switch product {
        case .KLEOS:
            return true
        case .WOLFCASTLE, .BAYWOLF:
            return false
        }
    }
    
    func connected(to product: Bose.Products) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedProduct = product
        }
    }
    
    func disconnected() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedProduct = nil
            self.batteryLevel = nil
            self.noiseCancelMode = nil
            self.bassControlStep = nil
        }
    }
    
    func setBatteryLevel(_ level: Int?) {
        DispatchQueue.main.async {
            self.batteryLevel = level
        }
    }
    
    func setNoiseCancelMode(_ mode: Bose.AnrMode?) {
        DispatchQueue.main.async {
            self.noiseCancelMode = mode
        }
        
        if let mode = mode {
            delegate?.noiseCancelModeSelected(mode)
        }
    }
    
    func setBassControlStep(_ step: Int?) {
        DispatchQueue.main.async {
            self.bassControlStep = step
        }
        
        if let step = step {
            delegate?.bassControlStepSelected(step)
        }
    }
}

@available(macOS 11.0, *)
protocol AppStateDelegate: AnyObject {
    func noiseCancelModeSelected(_ mode: Bose.AnrMode)
    func bassControlStepSelected(_ step: Int)
}

@available(macOS 11.0, *)
class SwiftUIAppDelegate: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var appState = AppState()
    private var bt: Bt!
    private var statusUpdateTimer: Timer?
    
    func setBluetoothInstance(_ bt: Bt) {
        self.bt = bt
        
        // Set up app state delegate
        appState.delegate = self
        
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
        
        // Create popover with simple view for now
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: 
            SwiftUIContentView()
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

@available(macOS 11.0, *)
extension SwiftUIAppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    func onConnect() {
        NSLog("[NoQCNoLife]: SwiftUI onConnect() called")
        guard let product = Bose.Products.getById(self.bt.getProductId()) else {
            NSLog("[NoQCNoLife]: ERROR - Invalid product id in SwiftUI onConnect()")
            return
        }
        NSLog("[NoQCNoLife]: SwiftUI Connected to \(product.getName())")
        
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
                NSLog("[NoQCNoLife]: SwiftUI Stopping initial status polling")
                timer.invalidate()
                self.statusUpdateTimer = nil
            }
        }
        
        // Request battery level and noise cancellation mode after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            NSLog("[NoQCNoLife]: SwiftUI Requesting initial battery level and ANR mode")
            
            if !self.bt.sendGetBatteryLevelPacket() {
                NSLog("[NoQCNoLife]: SwiftUI Failed to send battery level packet")
                self.batteryLevelStatus(nil)
            }
            
            if !self.bt.sendGetAnrModePacket() {
                NSLog("[NoQCNoLife]: SwiftUI Failed to send ANR mode packet")
                self.noiseCancelModeChanged(nil)
            }
        }
    }
    
    func onDisconnect() {
        NSLog("[NoQCNoLife]: SwiftUI Disconnected")
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
        appState.disconnected()
        updateStatusBarIcon(for: nil)
    }
    
    func bassControlStepChanged(_ step: Int?) {
        NSLog("[NoQCNoLife]: SwiftUI Bass control step changed: \(step?.description ?? "nil")")
        appState.setBassControlStep(step)
    }
    
    func batteryLevelStatus(_ level: Int?) {
        NSLog("[NoQCNoLife]: SwiftUI Battery level: \(level?.description ?? "nil")")
        appState.setBatteryLevel(level)
    }
    
    func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        NSLog("[NoQCNoLife]: SwiftUI Noise cancel mode changed: \(mode?.toString() ?? "nil")")
        appState.setNoiseCancelMode(mode)
        updateStatusBarIcon(for: mode)
        
        if let mode = mode, let product = Bose.Products.getById(self.bt.getProductId()) {
            PreferenceManager.setLastSelectedAnrMode(product: product, anrMode: mode)
        }
    }
    
    // MARK: - DeviceManagementEventHandler
    
    func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        // Forward to connections window if needed
        NSLog("[NoQCNoLife]: SwiftUI received device list with \(devices.count) devices")
    }
    
    func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        NSLog("[NoQCNoLife]: SwiftUI received device info for \(deviceInfo.macAddress)")
    }
}

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

// MARK: - SwiftUI Views

@available(macOS 11.0, *)
struct SwiftUIContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            if appState.isConnected, let product = appState.connectedProduct {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundColor(.green)
                        Text(product.getName())
                            .font(.headline)
                        Spacer()
                    }
                    
                    if let batteryLevel = appState.batteryLevel {
                        HStack {
                            Image(systemName: "battery.100")
                                .foregroundColor(.green)
                            Text("Battery: \(batteryLevel)%")
                                .font(.subheadline)
                        }
                    }
                    
                    if let anrMode = appState.noiseCancelMode {
                        HStack {
                            Image(systemName: "speaker.wave.3")
                                .foregroundColor(.blue)
                            Text("NC: \(anrMode.toString())")
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                
                if appState.supportsNoiseCancellation {
                    VStack {
                        Text("Noise Cancellation")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 8) {
                            Button("High") {
                                appState.setNoiseCancelMode(.HIGH)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Low") {
                                appState.setNoiseCancelMode(.LOW)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Off") {
                                appState.setNoiseCancelMode(.OFF)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
                
                if appState.supportsBassControl {
                    VStack {
                        Text("Bass Control")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Button("-") {
                                if let current = appState.bassControlStep, current > -8 {
                                    appState.setBassControlStep(current - 1)
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Text("\(appState.bassControlStep ?? 0)")
                                .frame(width: 30)
                                .font(.system(.body, design: .monospaced))
                            
                            Button("+") {
                                if let current = appState.bassControlStep, current < 8 {
                                    appState.setBassControlStep(current + 1)
                                } else if appState.bassControlStep == nil {
                                    appState.setBassControlStep(0)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "headphones")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No device connected.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Divider()
            
            VStack(spacing: 8) {
                Button("Connections...") {
                    ConnectionsWindowController.shared.showWindow()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("About") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .frame(width: 250)
    }
}
