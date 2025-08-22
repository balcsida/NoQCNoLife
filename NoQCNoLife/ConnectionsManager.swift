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
import Combine

@MainActor
final class ConnectionsManager: ObservableObject {
    static let shared = ConnectionsManager()
    
    @Published var devices: [BosePairedDevice] = []
    @Published var isLoading = false
    @Published var isPairingModeActive = false
    @Published var connectedDeviceCount = 0
    @Published var hasConnection = false
    
    nonisolated init() {}
    
    func refreshDevices(using bt: Bt) {
        isLoading = true
        devices.removeAll()
        hasConnection = bt.getProductId() != nil
        
        if hasConnection {
            _ = bt.sendListDevicesPacket()
        } else {
            isLoading = false
        }
    }
    
    func connectToDevice(_ device: BosePairedDevice, using bt: Bt, completion: @escaping (Result<Void, Error>) -> Void) {
        let macAddressBytes = parseMacAddress(device.address)
        let success = bt.sendConnectDevicePacket(macAddress: macAddressBytes)
        
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshDevices(using: bt)
            }
            completion(.success(()))
        } else {
            completion(.failure(ConnectionError.sendFailed))
        }
    }
    
    func disconnectFromDevice(_ device: BosePairedDevice, using bt: Bt, completion: @escaping (Result<Void, Error>) -> Void) {
        let macAddressBytes = parseMacAddress(device.address)
        let success = bt.sendDisconnectDevicePacket(macAddress: macAddressBytes)
        
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshDevices(using: bt)
            }
            completion(.success(()))
        } else {
            completion(.failure(ConnectionError.sendFailed))
        }
    }
    
    func removeDevicePairing(_ device: BosePairedDevice, using bt: Bt, completion: @escaping (Result<Void, Error>) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Remove Device Pairing"
        alert.informativeText = "Are you sure you want to remove the pairing for \"\(device.displayName)\"?\n\nThis will permanently delete the device from the Bose headphone's paired device list."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let macAddressBytes = parseMacAddress(device.address)
            let success = bt.sendRemoveDevicePacket(macAddress: macAddressBytes)
            
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.refreshDevices(using: bt)
                }
                completion(.success(()))
            } else {
                completion(.failure(ConnectionError.sendFailed))
            }
        }
    }
    
    func togglePairingMode(using bt: Bt, completion: @escaping (Result<Void, Error>) -> Void) {
        let success: Bool
        if isPairingModeActive {
            success = bt.sendExitPairingModePacket()
        } else {
            success = bt.sendEnterPairingModePacket()
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
            self.isLoading = false
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