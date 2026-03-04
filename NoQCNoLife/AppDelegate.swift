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
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private(set) var bt: Bt?
    private var connectNotification: IOBluetoothUserNotification?
    let appState = AppState()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("[NoQCNoLife]: applicationDidFinishLaunching called")

        // Initialize Bluetooth
        bt = Bt(self)
        BluetoothManager.shared.setBluetooth(bt!)

        // Set up the menu bar status item
        setupStatusItem()
        NSLog("[NoQCNoLife]: statusItem = \(String(describing: statusItem)), button = \(String(describing: statusItem?.button)), image = \(String(describing: statusItem?.button?.image))")

        // Set up the SwiftUI popover
        setupPopover()

        // Register for Bluetooth connect notifications to detect new connections
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: bt,
                                                          selector: #selector(Bt.onNewConnectionDetected))

        // Check for already-connected Bose devices
        bt?.checkForConnectedDevices()

        NSLog("[NoQCNoLife]: Application launched, Bluetooth initialized")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        bt?.closeConnection()
    }

    // MARK: - Status Item & Popover Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "NoQCNoLife") {
                image.size = NSSize(width: 16, height: 16)
                button.image = image
            } else {
                button.title = "QC"
            }
            button.toolTip = "No QC, No Life"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 420)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MainContentView()
                .environmentObject(appState)
                .environmentObject(self)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if let popover = popover {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - User Actions (called from SwiftUI views)

    func userSelectedNoiseCancelMode(_ mode: Bose.AnrMode) {
        _ = bt?.sendSetGetAnrModePacket(mode)
    }

    func userSelectedBassControlStep(_ step: Int) {
        _ = bt?.sendSetGetBassControlPacket(step)
    }

    func showConnectionsWindow() {
        popover?.performClose(nil)
        ConnectionsWindowController.shared.showWindow()
    }

    func showDebugWindow() {
        popover?.performClose(nil)
        DebugWindowController.shared.showWindow()
    }
}

// MARK: - Bluetooth Delegate

extension AppDelegate: BluetoothDelegate, DeviceManagementEventHandler {

    nonisolated func onConnect() {
        Task { @MainActor in
            appState.isConnected = true
            if let productId = bt?.getProductId() {
                appState.connectedProduct = Bose.Products.getById(productId)
            }
            NSLog("[NoQCNoLife]: Device connected")

            // Query current device state
            _ = bt?.sendGetBatteryLevelPacket()
            _ = bt?.sendGetAnrModePacket()
            _ = bt?.sendGetBassControlPacket()
        }
    }

    nonisolated func onDisconnect() {
        Task { @MainActor in
            appState.isConnected = false
            appState.connectedProduct = nil
            appState.batteryLevel = nil
            appState.noiseCancelMode = nil
            appState.bassControlStep = nil
            NSLog("[NoQCNoLife]: Device disconnected")
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
            if let mode = mode {
                if let product = appState.connectedProduct {
                    PreferenceManager.setLastSelectedAnrMode(product: product, anrMode: mode)
                }
            }
        }
    }

    nonisolated func bassControlStepChanged(_ step: Int?) {
        Task { @MainActor in
            appState.bassControlStep = step
        }
    }

    nonisolated func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        Task { @MainActor in
            ConnectionsManager.shared.didReceiveDeviceList(devices)
            ConnectionsWindowController.shared.didReceiveDeviceList(devices)
        }
    }

    nonisolated func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        Task { @MainActor in
            ConnectionsManager.shared.onDeviceInfoReceived(deviceInfo)
        }
    }
}
