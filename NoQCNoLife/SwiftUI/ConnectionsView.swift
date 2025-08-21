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
struct ConnectionsView: View {
    @StateObject private var viewModel = ConnectionsViewModel()
    @State private var selectedDevice: BosePairedDevice?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.devices.isEmpty && !viewModel.isLoading {
                EmptyDeviceView()
            } else {
                DeviceListView()
            }
            
            Divider()
            
            ControlButtonsView()
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear {
            viewModel.refreshDevices()
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    @ViewBuilder
    private func EmptyDeviceView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "headphones")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Bose device connected.")
                    .font(.headline)
                Text("Please connect a Bose device first to manage its connections.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func DeviceListView() -> some View {
        Table(viewModel.devices, selection: $selectedDevice) {
            TableColumn("Device Name", value: \.displayName) { device in
                HStack {
                    Image(systemName: deviceIcon(for: device))
                        .foregroundColor(deviceIconColor(for: device))
                    Text(device.displayName)
                        .foregroundColor(device.status == .currentDevice ? .secondary : .primary)
                }
            }
            
            TableColumn("Status", value: \.statusText) { device in
                Text(device.statusText)
                    .foregroundColor(statusColor(for: device.status))
            }
            
            TableColumn("Address", value: \.address) { device in
                Text(device.address)
                    .font(.monospaced(.body)())
                    .foregroundColor(.secondary)
            }
        }
        .refreshable {
            await viewModel.refreshDevicesAsync()
        }
    }
    
    @ViewBuilder
    private func ControlButtonsView() -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button("Connect") {
                    connectToDevice()
                }
                .disabled(!canConnect)
                
                Button("Disconnect") {
                    disconnectFromDevice()
                }
                .disabled(!canDisconnect)
                
                Button("Remove Pairing") {
                    removePairing()
                }
                .disabled(!canRemovePairing)
                
                Spacer()
                
                Button("Refresh") {
                    viewModel.refreshDevices()
                }
            }
            
            Button(viewModel.isPairingModeActive ? "Exit Pairing Mode" : "Enter Pairing Mode") {
                togglePairingMode()
            }
            .disabled(!canTogglePairingMode)
            
            Text("Select a device to connect or disconnect")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func deviceIcon(for device: BosePairedDevice) -> String {
        switch device.status {
        case .currentDevice: return "laptopcomputer"
        case .connected: return "headphones"
        case .disconnected: return "headphones.circle"
        }
    }
    
    private func deviceIconColor(for device: BosePairedDevice) -> Color {
        switch device.status {
        case .currentDevice: return .blue
        case .connected: return .green
        case .disconnected: return .orange
        }
    }
    
    private func statusColor(for status: DeviceConnectionStatus) -> Color {
        switch status {
        case .currentDevice: return .blue
        case .connected: return .green
        case .disconnected: return .orange
        }
    }
    
    private var canConnect: Bool {
        guard let device = selectedDevice else { return false }
        return device.status == .disconnected
    }
    
    private var canDisconnect: Bool {
        guard let device = selectedDevice else { return false }
        return device.status == .connected
    }
    
    private var canRemovePairing: Bool {
        guard let device = selectedDevice else { return false }
        return device.status != .currentDevice
    }
    
    private var canTogglePairingMode: Bool {
        viewModel.hasConnection && viewModel.connectedDeviceCount < 2
    }
    
    // MARK: - Actions
    
    private func connectToDevice() {
        guard let device = selectedDevice else { return }
        
        if device.status == .currentDevice {
            showAlert(title: "Cannot Connect", message: "You cannot connect to the current device where this app is running.")
            return
        }
        
        viewModel.connectToDevice(device) { result in
            switch result {
            case .success:
                break // Success handled by refresh
            case .failure(let error):
                showAlert(title: "Connection Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func disconnectFromDevice() {
        guard let device = selectedDevice else { return }
        
        if device.status == .currentDevice {
            showAlert(title: "Cannot Disconnect", message: "You cannot disconnect from the current device where this app is running.")
            return
        }
        
        viewModel.disconnectFromDevice(device) { result in
            switch result {
            case .success:
                break // Success handled by refresh
            case .failure(let error):
                showAlert(title: "Disconnection Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func removePairing() {
        guard let device = selectedDevice else { return }
        
        if device.status == .currentDevice {
            showAlert(title: "Cannot Remove Pairing", message: "You cannot remove the pairing for the current device where this app is running.")
            return
        }
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Remove Device Pairing"
        alert.informativeText = "Are you sure you want to remove the pairing for \"\(device.displayName)\"?\n\nThis will permanently delete the device from the Bose headphone's paired device list."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            viewModel.removeDevicePairing(device) { result in
                switch result {
                case .success:
                    break // Success handled by refresh
                case .failure(let error):
                    showAlert(title: "Remove Pairing Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func togglePairingMode() {
        if !viewModel.hasConnection {
            showAlert(title: "No Bose Device Connected", message: "Please connect a Bose device first to control pairing mode.")
            return
        }
        
        if !viewModel.isPairingModeActive && viewModel.connectedDeviceCount >= 2 {
            showAlert(title: "Maximum Connections Reached", message: "The headphone already has 2 devices connected, which is the maximum. Please disconnect a device before entering pairing mode.")
            return
        }
        
        viewModel.togglePairingMode { result in
            switch result {
            case .success:
                break // Success handled by state update
            case .failure(let error):
                showAlert(title: "Pairing Mode Error", message: error.localizedDescription)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

@available(macOS 11.0, *)
class ConnectionsViewModel: ObservableObject {
    @Published var devices: [BosePairedDevice] = []
    @Published var isLoading = false
    @Published var isPairingModeActive = false
    @Published var connectedDeviceCount = 0
    @Published var hasConnection = false
    
    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }
    
    func refreshDevices() {
        Task {
            await refreshDevicesAsync()
        }
    }
    
    @MainActor
    func refreshDevicesAsync() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let appDelegate = appDelegate else {
            print("Error: Cannot access AppDelegate")
            return
        }
        
        devices.removeAll()
        hasConnection = appDelegate.bt.getProductId() != nil
        
        if hasConnection {
            _ = appDelegate.bt.sendListDevicesPacket()
            
            // Wait a moment for the response
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
    
    func connectToDevice(_ device: BosePairedDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let appDelegate = appDelegate else {
            completion(.failure(ConnectionError.noAppDelegate))
            return
        }
        
        let macAddressBytes = parseMacAddress(device.address)
        let success = appDelegate.bt.sendConnectDevicePacket(macAddress: macAddressBytes)
        
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshDevices()
            }
            completion(.success(()))
        } else {
            completion(.failure(ConnectionError.sendFailed))
        }
    }
    
    func disconnectFromDevice(_ device: BosePairedDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let appDelegate = appDelegate else {
            completion(.failure(ConnectionError.noAppDelegate))
            return
        }
        
        let macAddressBytes = parseMacAddress(device.address)
        let success = appDelegate.bt.sendDisconnectDevicePacket(macAddress: macAddressBytes)
        
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshDevices()
            }
            completion(.success(()))
        } else {
            completion(.failure(ConnectionError.sendFailed))
        }
    }
    
    func removeDevicePairing(_ device: BosePairedDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let appDelegate = appDelegate else {
            completion(.failure(ConnectionError.noAppDelegate))
            return
        }
        
        let macAddressBytes = parseMacAddress(device.address)
        let success = appDelegate.bt.sendRemoveDevicePacket(macAddress: macAddressBytes)
        
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshDevices()
            }
            completion(.success(()))
        } else {
            completion(.failure(ConnectionError.sendFailed))
        }
    }
    
    func togglePairingMode(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let appDelegate = appDelegate else {
            completion(.failure(ConnectionError.noAppDelegate))
            return
        }
        
        let success: Bool
        if isPairingModeActive {
            success = appDelegate.bt.sendExitPairingModePacket()
        } else {
            success = appDelegate.bt.sendEnterPairingModePacket()
        }
        
        if success {
            completion(.success(()))
        } else {
            completion(.failure(ConnectionError.sendFailed))
        }
    }
    
    private func parseMacAddress(_ macString: String) -> [UInt8] {
        let components = macString.components(separatedBy: ":")
        return components.compactMap { UInt8($0, radix: 16) }
    }
    
    func didReceiveDeviceList(_ devices: [BosePairedDevice]) {
        DispatchQueue.main.async {
            self.devices = devices
            self.connectedDeviceCount = devices.filter { device in
                device.status == .connected || device.status == .currentDevice
            }.count
        }
    }
    
    func onPairingModeResponse(_ isEnabled: Bool) {
        DispatchQueue.main.async {
            self.isPairingModeActive = isEnabled
        }
    }
    
    func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        DispatchQueue.main.async {
            for i in 0..<self.devices.count {
                if self.devices[i].address.uppercased() == deviceInfo.macAddress.uppercased() {
                    let status: DeviceConnectionStatus = deviceInfo.isLocalDevice ? .currentDevice :
                                                        (deviceInfo.isConnected ? .connected : .disconnected)
                    
                    let updatedDevice = BosePairedDevice(
                        name: deviceInfo.deviceName ?? self.devices[i].name,
                        address: self.devices[i].address,
                        status: status,
                        deviceInfo: self.devices[i].deviceInfo
                    )
                    
                    self.devices[i] = updatedDevice
                    break
                }
            }
            
            self.connectedDeviceCount = self.devices.filter { device in
                device.status == .connected || device.status == .currentDevice
            }.count
        }
    }
}

extension BosePairedDevice {
    var displayName: String {
        let baseName = name ?? "Unknown Device"
        return status == .currentDevice ? "\(baseName) (Current Device)" : baseName
    }
    
    var statusText: String {
        switch status {
        case .currentDevice: return "Current"
        case .connected: return "Connected"
        case .disconnected: return "Paired (Disconnected)"
        }
    }
}

enum ConnectionError: LocalizedError {
    case noAppDelegate
    case sendFailed
    
    var errorDescription: String? {
        switch self {
        case .noAppDelegate: return "Cannot access application delegate"
        case .sendFailed: return "Failed to send command to device"
        }
    }
}

@available(macOS 11.0, *)
#Preview {
    ConnectionsView()
}