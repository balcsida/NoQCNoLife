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

struct ConnectionsView: View {
    @StateObject private var manager = ConnectionsManager.shared
    @State private var selectedDevice: BosePairedDevice?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Device Connections")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            if manager.devices.isEmpty && !manager.isLoading {
                EmptyDeviceView()
            } else {
                DeviceListView(selectedDevice: $selectedDevice)
            }
            
            Divider()
            
            ControlButtonsView(selectedDevice: $selectedDevice)
        }
        .frame(width: 600, height: 450)
        .onAppear {
            if let bt = BluetoothManager.shared.bt {
                manager.refreshDevices(using: bt)
            }
        }
    }
}

private struct EmptyDeviceView: View {
    var body: some View {
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
}

private struct DeviceListView: View {
    @ObservedObject var manager = ConnectionsManager.shared
    @Binding var selectedDevice: BosePairedDevice?
    
    var body: some View {
        List(manager.devices, selection: $selectedDevice) { device in
            HStack {
                VStack(alignment: .leading) {
                    Text(device.displayName)
                        .font(.system(.body))
                    Text(device.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(device.statusText)
                    .font(.caption)
                    .foregroundColor(statusColor(for: device.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(statusColor(for: device.status).opacity(0.2))
                    )
            }
            .padding(.vertical, 4)
        }
    }
    
    private func statusColor(for status: DeviceConnectionStatus) -> Color {
        switch status {
        case .currentDevice: return .blue
        case .connected: return .green
        case .disconnected: return .orange
        }
    }
}

private struct ControlButtonsView: View {
    @ObservedObject var manager = ConnectionsManager.shared
    @Binding var selectedDevice: BosePairedDevice?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showingRemoveConfirmation = false

    var body: some View {
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
                    showingRemoveConfirmation = true
                }
                .disabled(!canRemovePairing)

                Spacer()

                Button("Refresh") {
                    if let bt = BluetoothManager.shared.bt {
                        manager.refreshDevices(using: bt)
                    }
                }
            }

            Button(manager.isPairingModeActive ? "Exit Pairing Mode" : "Enter Pairing Mode") {
                togglePairingMode()
            }
            .disabled(!canTogglePairingMode)

            Text("Select a device to connect or disconnect")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Remove Device Pairing",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                removePairing()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let device = selectedDevice {
                Text("Are you sure you want to remove the pairing for \"\(device.displayName)\"?\n\nThis will permanently delete the device from the Bose headphone's paired device list.")
            }
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
        manager.hasConnection && manager.connectedDeviceCount < 2
    }
    
    private func connectToDevice() {
        guard let device = selectedDevice else { return }
        
        if device.status == .currentDevice {
            showAlert(title: "Cannot Connect", message: "You cannot connect to the current device where this app is running.")
            return
        }
        
        guard let bt = BluetoothManager.shared.bt else {
            showAlert(title: "Not Connected", message: "Bluetooth is not initialized")
            return
        }
        manager.connectToDevice(device, using: bt) { result in
            switch result {
            case .success:
                break
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
        
        guard let bt = BluetoothManager.shared.bt else {
            showAlert(title: "Not Connected", message: "Bluetooth is not initialized")
            return
        }
        manager.disconnectFromDevice(device, using: bt) { result in
            switch result {
            case .success:
                break
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
        
        // Confirmation is handled inside the manager
        guard let bt = BluetoothManager.shared.bt else {
            showAlert(title: "Not Connected", message: "Bluetooth is not initialized")
            return
        }
        manager.removeDevicePairing(device, using: bt) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                showAlert(title: "Remove Pairing Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func togglePairingMode() {
        if !manager.hasConnection {
            showAlert(title: "No Bose Device Connected", message: "Please connect a Bose device first to control pairing mode.")
            return
        }
        
        if !manager.isPairingModeActive && manager.connectedDeviceCount >= 2 {
            showAlert(title: "Maximum Connections Reached", message: "The headphone already has 2 devices connected, which is the maximum. Please disconnect a device before entering pairing mode.")
            return
        }
        
        guard let bt = BluetoothManager.shared.bt else {
            showAlert(title: "Not Connected", message: "Bluetooth is not initialized")
            return
        }
        manager.togglePairingMode(using: bt) { result in
            switch result {
            case .success:
                break
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

extension BosePairedDevice: Identifiable {
    var id: String { address }
    
    var displayName: String {
        let baseName = name ?? "Unknown Device"
        return status == .currentDevice ? "\(baseName) (Current Device)" : baseName
    }
    
    var statusText: String {
        switch status {
        case .currentDevice: return "Current"
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        }
    }
}