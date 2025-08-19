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
import IOBluetooth

struct BoseConnectedDevice {
    let name: String?
    let address: String
    let isConnected: Bool
    let isCurrentDevice: Bool
}

protocol DeviceListDelegate: AnyObject {
    func didReceiveDeviceList(_ devices: [BoseConnectedDevice])
}

class ConnectionsWindowController: NSWindowController, DeviceListDelegate {
    
    static let shared = ConnectionsWindowController()
    
    private var devicesTableView: NSTableView!
    private var connectButton: NSButton!
    private var disconnectButton: NSButton!
    private var refreshButton: NSButton!
    
    private var boseConnectedDevices: [BoseConnectedDevice] = []
    private var selectedDeviceIndex: Int = -1
    private var currentMacAddress: String?
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.title = "Device Connections"
        window.center()
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        let contentView = NSView(frame: window.contentView!.frame)
        window.contentView = contentView
        
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: 460, height: 280))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        
        devicesTableView = NSTableView()
        devicesTableView.headerView = nil
        devicesTableView.allowsMultipleSelection = false
        devicesTableView.allowsEmptySelection = true
        devicesTableView.delegate = self
        devicesTableView.dataSource = self
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Device Name"
        nameColumn.width = 200
        devicesTableView.addTableColumn(nameColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.width = 100
        devicesTableView.addTableColumn(statusColumn)
        
        let addressColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("address"))
        addressColumn.title = "Address"
        addressColumn.width = 140
        devicesTableView.addTableColumn(addressColumn)
        
        scrollView.documentView = devicesTableView
        contentView.addSubview(scrollView)
        
        connectButton = NSButton(frame: NSRect(x: 20, y: 40, width: 80, height: 32))
        connectButton.title = "Connect"
        connectButton.bezelStyle = .rounded
        connectButton.action = #selector(connectToDevice)
        connectButton.target = self
        connectButton.isEnabled = false
        contentView.addSubview(connectButton)
        
        disconnectButton = NSButton(frame: NSRect(x: 110, y: 40, width: 100, height: 32))
        disconnectButton.title = "Disconnect"
        disconnectButton.bezelStyle = .rounded
        disconnectButton.action = #selector(disconnectFromDevice)
        disconnectButton.target = self
        disconnectButton.isEnabled = false
        contentView.addSubview(disconnectButton)
        
        refreshButton = NSButton(frame: NSRect(x: 220, y: 40, width: 80, height: 32))
        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.action = #selector(refreshDevices)
        refreshButton.target = self
        contentView.addSubview(refreshButton)
        
        let statusLabel = NSTextField(frame: NSRect(x: 20, y: 10, width: 460, height: 20))
        statusLabel.stringValue = "Select a device to connect or disconnect"
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = NSColor.clear
        statusLabel.textColor = NSColor.secondaryLabelColor
        contentView.addSubview(statusLabel)
    }
    
    func showWindow() {
        refreshDevices()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func refreshDevices() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            print("Error: Cannot access AppDelegate")
            return
        }
        
        // Clear existing devices
        boseConnectedDevices.removeAll()
        devicesTableView.reloadData()
        updateButtonStates()
        
        // Get current Mac's Bluetooth address to identify it
        currentMacAddress = getCurrentDeviceBluetoothAddress()
        
        // Check if we have a connected Bose device
        guard appDelegate.bt.getProductId() != nil else {
            // Show message that no Bose device is connected
            let statusLabel = NSTextField(frame: NSRect(x: 20, y: 180, width: 460, height: 40))
            statusLabel.stringValue = "No Bose device connected.\nPlease connect a Bose device first to manage its connections."
            statusLabel.isEditable = false
            statusLabel.isBordered = false
            statusLabel.backgroundColor = NSColor.clear
            statusLabel.textColor = NSColor.secondaryLabelColor
            statusLabel.alignment = .center
            window?.contentView?.addSubview(statusLabel)
            return
        }
        
        // Send BMAP LIST_DEVICES command to get devices connected to the Bose headphone
        if !appDelegate.bt.sendListDevicesPacket() {
            print("Failed to send LIST_DEVICES packet to Bose device")
        }
        
        // Note: The response will be handled by the BMAP parsing system
        // and will call our delegate method when devices are received
    }
    
    private func getCurrentDeviceBluetoothAddress() -> String? {
        return IOBluetoothHostController.default()?.addressAsString()
    }
    
    private func processPnPInfo(_ device: IOBluetoothDevice) -> (venderId: Int, productId: Int)? {
        let uuid: BluetoothSDPUUID16 = 0x1200
        let spdUuid = IOBluetoothSDPUUID(uuid16: uuid)
        
        guard let serviceRecord = device.getServiceRecord(for: spdUuid),
              let venderId = serviceRecord.getAttributeDataElement(0x0201)?.getNumberValue(),
              let productId = serviceRecord.getAttributeDataElement(0x0202)?.getNumberValue() else {
            return nil
        }
        
        return (venderId.intValue, productId.intValue)
    }
    
    @objc private func connectToDevice() {
        guard selectedDeviceIndex >= 0 && selectedDeviceIndex < boseConnectedDevices.count else { return }
        
        let device = boseConnectedDevices[selectedDeviceIndex]
        
        if device.isCurrentDevice {
            let alert = NSAlert()
            alert.messageText = "Cannot Connect"
            alert.informativeText = "You cannot connect to the current device where this app is running."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            print("Error: Cannot access AppDelegate")
            return
        }
        
        let macAddressBytes = parseMacAddress(device.address)
        if appDelegate.bt.sendConnectDevicePacket(macAddress: macAddressBytes) {
            print("Sent connect command to device: \(device.name ?? "Unknown") (\(device.address))")
            // Refresh devices after a delay to see connection status
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshDevices()
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Connection Failed"
            alert.informativeText = "Failed to send connect command to the device."
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
    
    @objc private func disconnectFromDevice() {
        guard selectedDeviceIndex >= 0 && selectedDeviceIndex < boseConnectedDevices.count else { return }
        
        let device = boseConnectedDevices[selectedDeviceIndex]
        
        if device.isCurrentDevice {
            let alert = NSAlert()
            alert.messageText = "Cannot Disconnect"
            alert.informativeText = "You cannot disconnect from the current device where this app is running."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            print("Error: Cannot access AppDelegate")
            return
        }
        
        let macAddressBytes = parseMacAddress(device.address)
        if appDelegate.bt.sendDisconnectDevicePacket(macAddress: macAddressBytes) {
            print("Sent disconnect command to device: \(device.name ?? "Unknown") (\(device.address))")
            // Refresh devices after a delay to see connection status
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshDevices()
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Disconnection Failed"
            alert.informativeText = "Failed to send disconnect command to the device."
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
    
    private func parseMacAddress(_ macString: String) -> [UInt8] {
        let components = macString.components(separatedBy: ":")
        return components.compactMap { UInt8($0, radix: 16) }
    }
    
    // MARK: - DeviceListDelegate
    
    func didReceiveDeviceList(_ devices: [BoseConnectedDevice]) {
        DispatchQueue.main.async {
            self.boseConnectedDevices = devices
            self.devicesTableView.reloadData()
            self.updateButtonStates()
        }
    }
    
    private func updateButtonStates() {
        let hasValidSelection = selectedDeviceIndex >= 0 && selectedDeviceIndex < boseConnectedDevices.count
        
        if hasValidSelection {
            let device = boseConnectedDevices[selectedDeviceIndex]
            
            if device.isCurrentDevice {
                connectButton.isEnabled = false
                disconnectButton.isEnabled = false
            } else {
                connectButton.isEnabled = !device.isConnected
                disconnectButton.isEnabled = device.isConnected
            }
        } else {
            connectButton.isEnabled = false
            disconnectButton.isEnabled = false
        }
    }
}

extension ConnectionsWindowController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return boseConnectedDevices.count
    }
}

extension ConnectionsWindowController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < boseConnectedDevices.count else { return nil }
        
        let device = boseConnectedDevices[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        let cellView = NSTextField()
        cellView.isBordered = false
        cellView.isEditable = false
        cellView.backgroundColor = NSColor.clear
        
        switch identifier {
        case "name":
            cellView.stringValue = device.name ?? "Unknown Device"
            if device.isCurrentDevice {
                cellView.stringValue += " (Current Device)"
                cellView.textColor = NSColor.secondaryLabelColor
            }
        case "status":
            if device.isCurrentDevice {
                cellView.stringValue = "Current"
                cellView.textColor = NSColor.systemBlue
            } else if device.isConnected {
                cellView.stringValue = "Connected"
                cellView.textColor = NSColor.systemGreen
            } else {
                cellView.stringValue = "Disconnected"
                cellView.textColor = NSColor.secondaryLabelColor
            }
        case "address":
            cellView.stringValue = device.address
            cellView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        default:
            return nil
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedDeviceIndex = devicesTableView.selectedRow
        updateButtonStates()
    }
}