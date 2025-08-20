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

protocol DeviceListDelegate: AnyObject {
    func didReceiveDeviceList(_ devices: [BosePairedDevice])
}

class ConnectionsWindowController: NSWindowController, DeviceListDelegate {
    
    static let shared = ConnectionsWindowController()
    
    private var devicesTableView: NSTableView!
    private var connectButton: NSButton!
    private var disconnectButton: NSButton!
    private var removePairingButton: NSButton!
    private var refreshButton: NSButton!
    private var pairingModeButton: NSButton!
    
    private var bosePairedDevices: [BosePairedDevice] = []
    private var selectedDeviceIndex: Int = -1
    private var currentMacAddress: String?
    private var isPairingModeActive: Bool = false
    private var noDeviceLabel: NSTextField?
    private var connectedDeviceCount: Int = 0
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
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
        
        // Make window wider by default
        window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 600, height: 450), display: true)
        
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView
        
        // Create scroll view for devices table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        
        devicesTableView = NSTableView()
        devicesTableView.headerView = nil
        devicesTableView.allowsMultipleSelection = false
        devicesTableView.allowsEmptySelection = true
        devicesTableView.delegate = self
        devicesTableView.dataSource = self
        
        // Make columns wider by default
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Device Name"
        nameColumn.width = 250
        nameColumn.resizingMask = [.autoresizingMask]
        devicesTableView.addTableColumn(nameColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.width = 120
        statusColumn.resizingMask = [.autoresizingMask]
        devicesTableView.addTableColumn(statusColumn)
        
        let addressColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("address"))
        addressColumn.title = "Address"
        addressColumn.width = 180
        addressColumn.resizingMask = [.autoresizingMask]
        devicesTableView.addTableColumn(addressColumn)
        
        scrollView.documentView = devicesTableView
        contentView.addSubview(scrollView)
        
        // Create buttons
        connectButton = NSButton()
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.title = "Connect"
        connectButton.bezelStyle = .rounded
        connectButton.action = #selector(connectToDevice)
        connectButton.target = self
        connectButton.isEnabled = false
        contentView.addSubview(connectButton)
        
        disconnectButton = NSButton()
        disconnectButton.translatesAutoresizingMaskIntoConstraints = false
        disconnectButton.title = "Disconnect"
        disconnectButton.bezelStyle = .rounded
        disconnectButton.action = #selector(disconnectFromDevice)
        disconnectButton.target = self
        disconnectButton.isEnabled = false
        contentView.addSubview(disconnectButton)
        
        removePairingButton = NSButton()
        removePairingButton.translatesAutoresizingMaskIntoConstraints = false
        removePairingButton.title = "Remove Pairing"
        removePairingButton.bezelStyle = .rounded
        removePairingButton.action = #selector(removePairing)
        removePairingButton.target = self
        removePairingButton.isEnabled = false
        contentView.addSubview(removePairingButton)
        
        refreshButton = NSButton()
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.action = #selector(refreshDevices)
        refreshButton.target = self
        contentView.addSubview(refreshButton)
        
        pairingModeButton = NSButton()
        pairingModeButton.translatesAutoresizingMaskIntoConstraints = false
        pairingModeButton.title = "Enter Pairing Mode"
        pairingModeButton.bezelStyle = .rounded
        pairingModeButton.action = #selector(togglePairingMode)
        pairingModeButton.target = self
        contentView.addSubview(pairingModeButton)
        
        let statusLabel = NSTextField()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.stringValue = "Select a device to connect or disconnect"
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = NSColor.clear
        statusLabel.textColor = NSColor.secondaryLabelColor
        contentView.addSubview(statusLabel)
        
        // Setup Auto Layout constraints
        NSLayoutConstraint.activate([
            // Scroll view - fills most of the window, leaving space for buttons at bottom
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: connectButton.topAnchor, constant: -20),
            
            // First row of buttons
            connectButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            connectButton.bottomAnchor.constraint(equalTo: pairingModeButton.topAnchor, constant: -15),
            connectButton.widthAnchor.constraint(equalToConstant: 80),
            connectButton.heightAnchor.constraint(equalToConstant: 32),
            
            disconnectButton.leadingAnchor.constraint(equalTo: connectButton.trailingAnchor, constant: 10),
            disconnectButton.centerYAnchor.constraint(equalTo: connectButton.centerYAnchor),
            disconnectButton.widthAnchor.constraint(equalToConstant: 100),
            disconnectButton.heightAnchor.constraint(equalToConstant: 32),
            
            removePairingButton.leadingAnchor.constraint(equalTo: disconnectButton.trailingAnchor, constant: 10),
            removePairingButton.centerYAnchor.constraint(equalTo: connectButton.centerYAnchor),
            removePairingButton.widthAnchor.constraint(equalToConstant: 120),
            removePairingButton.heightAnchor.constraint(equalToConstant: 32),
            
            refreshButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            refreshButton.centerYAnchor.constraint(equalTo: connectButton.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 80),
            refreshButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Pairing mode button - centered horizontally
            pairingModeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            pairingModeButton.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -15),
            pairingModeButton.widthAnchor.constraint(equalToConstant: 140),
            pairingModeButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Status label - bottom of window
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
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
        bosePairedDevices.removeAll()
        devicesTableView.reloadData()
        updateButtonStates()
        updatePairingModeButton()
        
        // Remove any existing "no device" message
        noDeviceLabel?.removeFromSuperview()
        noDeviceLabel = nil
        
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
            noDeviceLabel = statusLabel
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
        guard selectedDeviceIndex >= 0 && selectedDeviceIndex < bosePairedDevices.count else { return }
        
        let device = bosePairedDevices[selectedDeviceIndex]
        
        if device.status == .currentDevice {
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
        guard selectedDeviceIndex >= 0 && selectedDeviceIndex < bosePairedDevices.count else { return }
        
        let device = bosePairedDevices[selectedDeviceIndex]
        
        if device.status == .currentDevice {
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
    
    @objc private func removePairing() {
        guard selectedDeviceIndex >= 0 && selectedDeviceIndex < bosePairedDevices.count else { return }
        
        let device = bosePairedDevices[selectedDeviceIndex]
        
        if device.status == .currentDevice {
            let alert = NSAlert()
            alert.messageText = "Cannot Remove Pairing"
            alert.informativeText = "You cannot remove the pairing for the current device where this app is running."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Remove Device Pairing"
        alert.informativeText = "Are you sure you want to remove the pairing for \"\(device.name ?? "Unknown Device")\"?\n\nThis will permanently delete the device from the Bose headphone's paired device list."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            guard let appDelegate = NSApp.delegate as? AppDelegate else {
                print("Error: Cannot access AppDelegate")
                return
            }
            
            let macAddressBytes = parseMacAddress(device.address)
            if appDelegate.bt.sendRemoveDevicePacket(macAddress: macAddressBytes) {
                print("Sent remove pairing command for device: \(device.name ?? "Unknown") (\(device.address))")
                // Refresh devices after a delay to see updated list
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.refreshDevices()
                }
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Remove Pairing Failed"
                errorAlert.informativeText = "Failed to send remove pairing command to the device."
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }
    
    private func parseMacAddress(_ macString: String) -> [UInt8] {
        let components = macString.components(separatedBy: ":")
        return components.compactMap { UInt8($0, radix: 16) }
    }
    
    @objc private func togglePairingMode() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            print("Error: Cannot access AppDelegate")
            return
        }
        
        // Check if we have a connected Bose device
        guard appDelegate.bt.getProductId() != nil else {
            let alert = NSAlert()
            alert.messageText = "No Bose Device Connected"
            alert.informativeText = "Please connect a Bose device first to control pairing mode."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        // Check if we've reached the connection limit
        if !isPairingModeActive && connectedDeviceCount >= 2 {
            let alert = NSAlert()
            alert.messageText = "Maximum Connections Reached"
            alert.informativeText = "The headphone already has 2 devices connected, which is the maximum. Please disconnect a device before entering pairing mode."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        if isPairingModeActive {
            // Exit pairing mode
            if appDelegate.bt.sendExitPairingModePacket() {
                print("Sent exit pairing mode command")
                // Note: The actual state will be updated when we receive the response
                // For now, optimistically update the UI
                isPairingModeActive = false
                pairingModeButton.title = "Enter Pairing Mode"
            } else {
                let alert = NSAlert()
                alert.messageText = "Failed to Exit Pairing Mode"
                alert.informativeText = "Failed to send exit pairing mode command to the device."
                alert.alertStyle = .critical
                alert.runModal()
            }
        } else {
            // Enter pairing mode
            if appDelegate.bt.sendEnterPairingModePacket() {
                print("Sent enter pairing mode command")
                // Note: If the device rejects it (e.g., due to max connections), 
                // we'll handle that in the response
                
                // Wait a moment for the response, then check if it succeeded
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    // The response handler should have updated isPairingModeActive by now
                    // If it's still false, the command was likely rejected
                    if !(self?.isPairingModeActive ?? false) {
                        let alert = NSAlert()
                        alert.messageText = "Unable to Enter Pairing Mode"
                        alert.informativeText = "The headphone cannot enter pairing mode. This usually happens when the maximum number of connections (2) has been reached."
                        alert.alertStyle = .warning
                        alert.runModal()
                    } else {
                        // Successfully entered pairing mode
                        self?.pairingModeButton.title = "Exit Pairing Mode"
                        
                        // Auto-refresh devices after a few seconds to see newly paired devices
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self?.refreshDevices()
                        }
                    }
                }
            } else {
                let alert = NSAlert()
                alert.messageText = "Failed to Enter Pairing Mode"
                alert.informativeText = "Failed to send enter pairing mode command to the device."
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }
    
    // MARK: - DeviceListDelegate
    
    func didReceiveDeviceList(_ devices: [BosePairedDevice]) {
        DispatchQueue.main.async {
            self.bosePairedDevices = devices
            
            // Initially assume all devices take slots, but we'll update this
            // after we get INFO responses that tell us actual connection status
            self.connectedDeviceCount = devices.count
            
            print("Device list received with \(devices.count) devices in paired list")
            
            self.devicesTableView.reloadData()
            self.updateButtonStates()
            self.updatePairingModeButton()
            
            // Now send INFO commands for each device to get accurate connection status
            guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
            
            for device in devices {
                if device.status != .currentDevice {
                    let macAddressBytes = self.parseMacAddress(device.address)
                    print("Requesting device info for: \(device.address)")
                    _ = appDelegate.bt.sendDeviceInfoPacket(macAddress: macAddressBytes)
                }
            }
        }
    }
    
    func onPairingModeResponse(_ isEnabled: Bool) {
        DispatchQueue.main.async {
            self.isPairingModeActive = isEnabled
            self.pairingModeButton.title = isEnabled ? "Exit Pairing Mode" : "Enter Pairing Mode"
            
            print("Pairing mode is now: \(isEnabled ? "enabled" : "disabled")")
        }
    }
    
    func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        DispatchQueue.main.async {
            // Find the device in our list and update its status
            for i in 0..<self.bosePairedDevices.count {
                if self.bosePairedDevices[i].address.uppercased() == deviceInfo.macAddress.uppercased() {
                    let status: DeviceConnectionStatus = deviceInfo.isLocalDevice ? .currentDevice : 
                                                        (deviceInfo.isConnected ? .connected : .disconnected)
                    
                    let updatedDevice = BosePairedDevice(
                        name: deviceInfo.deviceName ?? self.bosePairedDevices[i].name,
                        address: self.bosePairedDevices[i].address,
                        status: status,
                        deviceInfo: self.bosePairedDevices[i].deviceInfo
                    )
                    
                    self.bosePairedDevices[i] = updatedDevice
                    print("Updated device \(deviceInfo.macAddress): connected=\(deviceInfo.isConnected), name=\(deviceInfo.deviceName ?? "Unknown")")
                    break
                }
            }
            
            // Update connected device count based on actual connection status
            // Only count devices that are actively connected (connected or currentDevice)
            self.connectedDeviceCount = self.bosePairedDevices.filter { device in
                device.status == .connected || device.status == .currentDevice
            }.count
            
            print("Active connections: \(self.connectedDeviceCount)/2")
            
            // Reload the table to show updated status
            self.devicesTableView.reloadData()
            self.updateButtonStates()
            self.updatePairingModeButton()
        }
    }
    
    private func updateButtonStates() {
        let hasValidSelection = selectedDeviceIndex >= 0 && selectedDeviceIndex < bosePairedDevices.count
        
        if hasValidSelection {
            let device = bosePairedDevices[selectedDeviceIndex]
            
            switch device.status {
            case .currentDevice:
                connectButton.isEnabled = false
                disconnectButton.isEnabled = false
                removePairingButton.isEnabled = false
            case .connected:
                connectButton.isEnabled = false
                disconnectButton.isEnabled = true
                removePairingButton.isEnabled = true
            case .disconnected:
                connectButton.isEnabled = true
                disconnectButton.isEnabled = false
                removePairingButton.isEnabled = true
            }
        } else {
            connectButton.isEnabled = false
            disconnectButton.isEnabled = false
            removePairingButton.isEnabled = false
        }
    }
    
    private func updatePairingModeButton() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            pairingModeButton.isEnabled = false
            return
        }
        
        // Enable pairing mode button only if:
        // 1. We have a connected Bose device
        // 2. Less than 2 devices are actively connected
        // Note: The headphone might reject pairing if it has 2 devices in its list,
        // even if they're not connected. But we'll let the user try.
        let hasConnection = appDelegate.bt.getProductId() != nil
        let canPair = connectedDeviceCount < 2
        
        pairingModeButton.isEnabled = hasConnection && canPair
        
        // Update button tooltip to explain why it might be disabled
        if !hasConnection {
            pairingModeButton.toolTip = "Connect to a Bose device first"
        } else if !canPair {
            pairingModeButton.toolTip = "Maximum connections reached (2 devices)"
        } else {
            pairingModeButton.toolTip = "Put the headphone into pairing mode"
        }
    }
}

extension ConnectionsWindowController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return bosePairedDevices.count
    }
}

extension ConnectionsWindowController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < bosePairedDevices.count else { return nil }
        
        let device = bosePairedDevices[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        let cellView = NSTextField()
        cellView.isBordered = false
        cellView.isEditable = false
        cellView.backgroundColor = NSColor.clear
        
        switch identifier {
        case "name":
            cellView.stringValue = device.name ?? "Unknown Device"
            if device.status == .currentDevice {
                cellView.stringValue += " (Current Device)"
                cellView.textColor = NSColor.secondaryLabelColor
            }
        case "status":
            switch device.status {
            case .currentDevice:
                cellView.stringValue = "Current"
                cellView.textColor = NSColor.systemBlue
            case .connected:
                cellView.stringValue = "Connected"
                cellView.textColor = NSColor.systemGreen
            case .disconnected:
                cellView.stringValue = "Paired (Disconnected)"
                cellView.textColor = NSColor.systemOrange
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