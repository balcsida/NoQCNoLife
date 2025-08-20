/*
 Copyright (C) 2020 Shun Ito
 
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

import IOBluetooth

class DeviceManagementFunctionBlock: FunctionBlock {
    
    /*
     CONNECT = new FUNCTIONS("CONNECT", 2, (byte)1);
     DISCONNECT = new FUNCTIONS("DISCONNECT", 3, (byte)2);
     REMOVE_DEVICE = new FUNCTIONS("REMOVE_DEVICE", 4, (byte)3);
     LIST_DEVICES = new FUNCTIONS("LIST_DEVICES", 5, (byte)4);
     INFO = new FUNCTIONS("INFO", 6, (byte)5);
     EXTENDED_INFO = new FUNCTIONS("EXTENDED_INFO", 7, (byte)6);
     CLEAR_DEVICE_LIST = new FUNCTIONS("CLEAR_DEVICE_LIST", 8, (byte)7);
     PAIRING_MODE = new FUNCTIONS("PAIRING_MODE", 9, (byte)8);
     LOCAL_MAC_ADDRESS = new FUNCTIONS("LOCAL_MAC_ADDRESS", 10, (byte)9);
     PREPARE_P2P = new FUNCTIONS("PREPARE_P2P", 11, (byte)10);
     P2P_MODE = new FUNCTIONS("P2P_MODE", 12, (byte)11);
     ROUTING = new FUNCTIONS("ROUTING", 13, (byte)12);
     $VALUES = new FUNCTIONS[] {
     UNKNOWN, FUNCTION_BLOCK_INFO, CONNECT, DISCONNECT, REMOVE_DEVICE, LIST_DEVICES, INFO, EXTENDED_INFO, CLEAR_DEVICE_LIST, PAIRING_MODE,
     LOCAL_MAC_ADDRESS, PREPARE_P2P, P2P_MODE, ROUTING };
     */
    
    static let id = BmapPacket.FunctionBlockIds.DEVICE_MANAGEMENT
    
    static func parsePacket(bmapPacket: BmapPacket, eventHandler: EventHandler) {
        switch bmapPacket.getFunctionId() {
        case ConnectFunction.id:
            ConnectFunction.parsePacket(bmapPacket: bmapPacket, eventHandler: eventHandler)
        case DisconnectFunction.id:
            DisconnectFunction.parsePacket(bmapPacket: bmapPacket, eventHandler: eventHandler)
        case ListDevicesFunction.id:
            ListDevicesFunction.parsePacket(bmapPacket: bmapPacket, eventHandler: eventHandler)
        case RemoveDeviceFunction.id:
            RemoveDeviceFunction.parsePacket(bmapPacket: bmapPacket, eventHandler: eventHandler)
        case PairingModeFunction.id:
            PairingModeFunction.parsePacket(bmapPacket: bmapPacket, eventHandler: eventHandler)
        case InfoFunction.id:
            InfoFunction.parsePacket(bmapPacket: bmapPacket, eventHandler: eventHandler)
        case nil:
            assert(false, "Invalid function id.")
        default:
            print("Not implemented func: \(bmapPacket.getFunctionId()!) @ DeviceManagementFunctionBlock")
            print(bmapPacket.toString())
        }
    }
    
    static func generateListDevicesPacket() -> [Int8]? {
        let packet = BmapPacket(functionBlockId: id,
                               functionId: ListDevicesFunction.id,
                               operatorId: BmapPacket.OperatorIds.GET,
                               deviceId: 0,
                               port: 0,
                               payload: [])
        return packet.getPacket()
    }
    
    static func generateConnectDevicePacket(macAddress: [UInt8]) -> [Int8]? {
        guard macAddress.count == 6 else { return nil }
        var payload: [Int8] = [0x00]
        payload.append(contentsOf: macAddress.map { Int8(bitPattern: $0) })
        let packet = BmapPacket(functionBlockId: id,
                               functionId: ConnectFunction.id,
                               operatorId: BmapPacket.OperatorIds.START,
                               deviceId: 0,
                               port: 0,
                               payload: payload)
        return packet.getPacket()
    }
    
    static func generateDisconnectDevicePacket(macAddress: [UInt8]) -> [Int8]? {
        guard macAddress.count == 6 else { return nil }
        let payload = macAddress.map { Int8(bitPattern: $0) }
        let packet = BmapPacket(functionBlockId: id,
                               functionId: DisconnectFunction.id,
                               operatorId: BmapPacket.OperatorIds.START,
                               deviceId: 0,
                               port: 0,
                               payload: payload)
        return packet.getPacket()
    }
    
    static func generateRemoveDevicePacket(macAddress: [UInt8]) -> [Int8]? {
        guard macAddress.count == 6 else { return nil }
        let payload = macAddress.map { Int8(bitPattern: $0) }
        let packet = BmapPacket(functionBlockId: id,
                               functionId: RemoveDeviceFunction.id,
                               operatorId: BmapPacket.OperatorIds.START,
                               deviceId: 0,
                               port: 0,
                               payload: payload)
        return packet.getPacket()
    }
    
    static func generateEnterPairingModePacket() -> [Int8]? {
        let payload: [Int8] = [0x01] // Enable pairing mode
        let packet = BmapPacket(functionBlockId: id,
                               functionId: PairingModeFunction.id,
                               operatorId: BmapPacket.OperatorIds.START,  // Use START operator (5) as per BMAP spec
                               deviceId: 0,
                               port: 0,
                               payload: payload)
        return packet.getPacket()
    }
    
    static func generateExitPairingModePacket() -> [Int8]? {
        let payload: [Int8] = [0x00] // Disable pairing mode
        let packet = BmapPacket(functionBlockId: id,
                               functionId: PairingModeFunction.id,
                               operatorId: BmapPacket.OperatorIds.START,  // Use START operator (5) as per BMAP spec
                               deviceId: 0,
                               port: 0,
                               payload: payload)
        return packet.getPacket()
    }
    
    static func generateDeviceInfoPacket(macAddress: [UInt8]) -> [Int8]? {
        guard macAddress.count == 6 else { return nil }
        let payload = macAddress.map { Int8(bitPattern: $0) }
        let packet = BmapPacket(functionBlockId: id,
                               functionId: InfoFunction.id,
                               operatorId: BmapPacket.OperatorIds.GET,
                               deviceId: 0,
                               port: 0,
                               payload: payload)
        return packet.getPacket()
    }
}

private class ConnectFunction : Function {
    
    static let id: Int8 = 1

    static func parsePacket(bmapPacket: BmapPacket, eventHandler: EventHandler) {
//        print("[ConnectEvent]")
    }
}


private class DisconnectFunction: Function {
    
    static let id: Int8 = 2
    
    static func parsePacket(bmapPacket: BmapPacket, eventHandler: EventHandler) {
//        print("[DisconnectEvent]")
    }
}

private class RemoveDeviceFunction: Function {
    
    static let id: Int8 = 3
    
    static func parsePacket(bmapPacket: BmapPacket, eventHandler: EventHandler) {
        print("[RemoveDeviceEvent]: Device removal response received")
    }
}

private class ListDevicesFunction: Function {
    
    static let id: Int8 = 4
    
    static func parsePacket(bmapPacket: BmapPacket, eventHandler: EventHandler) {
        // According to BMAP docs, LIST_DEVICES response has operator STATUS (3)
        if bmapPacket.getOperatorId() == BmapPacket.OperatorIds.STATUS {
            guard let payload = bmapPacket.getPayload(), payload.count > 0 else {
                print("[ListDevicesEvent]: Empty payload")
                // Notify with empty list
                if let deviceEventHandler = eventHandler as? DeviceManagementEventHandler {
                    deviceEventHandler.onDeviceListReceived([])
                }
                return
            }
            
            let deviceCount = Int(UInt8(bitPattern: payload[0]))
            
            // The device count byte might not be accurate - calculate from payload size
            let actualDeviceCount = (payload.count - 1) / 6
            
            print("[ListDevicesEvent]: Device count byte says \(deviceCount), payload has room for \(actualDeviceCount) devices")
            print("[ListDevicesEvent]: Payload length: \(payload.count) bytes")
            
            // Use actual count based on payload size if it's larger than reported count
            let devicesToParse = max(deviceCount, actualDeviceCount)
            
            var devices: [BosePairedDevice] = []
            var offset = 1
            
            // Get current Mac's Bluetooth address to identify current device
            let currentMacAddress = IOBluetoothHostController.default()?.addressAsString()
            
            for i in 0..<devicesToParse {
                if offset + 6 <= payload.count {
                    let macAddress = Array(payload[offset..<(offset + 6)])
                    let macString = macAddress.map { String(format: "%02X", UInt8(bitPattern: $0)) }.joined(separator: ":")
                    print("[Device \(i)]: MAC Address: \(macString)")
                    
                    let isCurrentDevice = (macString == currentMacAddress)
                    
                    // Note: LIST_DEVICES returns all PAIRED devices, not just connected ones
                    // According to the new wiki, we should query each device with INFO command
                    // For now, we'll mark all non-current devices as "paired" and let INFO update the status
                    let connectionStatus: DeviceConnectionStatus
                    if isCurrentDevice {
                        connectionStatus = .currentDevice
                    } else {
                        // Default to disconnected - will be updated by INFO responses
                        connectionStatus = .disconnected
                    }
                    
                    let device = BosePairedDevice(
                        name: isCurrentDevice ? "This Mac" : getDeviceName(macAddress: macString),
                        address: macString,
                        status: connectionStatus,
                        deviceInfo: nil
                    )
                    
                    devices.append(device)
                    offset += 6
                } else {
                    break
                }
            }
            
            // Notify the event handler with the device list
            if let deviceEventHandler = eventHandler as? DeviceManagementEventHandler {
                deviceEventHandler.onDeviceListReceived(devices)
            }
        }
    }
    
    // Helper function to check if a device with given MAC address is currently connected to macOS
    private static func isDeviceConnected(macAddress: String) -> Bool {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() else { return false }
        
        for pairedDevice in pairedDevices {
            if let device = pairedDevice as? IOBluetoothDevice,
               let deviceAddress = device.addressString,
               deviceAddress.uppercased() == macAddress.uppercased() {
                return device.isConnected()
            }
        }
        return false
    }
    
    // Helper function to get device name from macOS Bluetooth
    private static func getDeviceName(macAddress: String) -> String? {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() else { return nil }
        
        for pairedDevice in pairedDevices {
            if let device = pairedDevice as? IOBluetoothDevice,
               let deviceAddress = device.addressString,
               deviceAddress.uppercased() == macAddress.uppercased() {
                return device.name
            }
        }
        return nil
    }
}

private class PairingModeFunction: Function {
    
    static let id: Int8 = 8
    
    static func parsePacket(bmapPacket: BmapPacket, eventHandler: EventHandler) {
        print("[PairingModeEvent]: Pairing mode response received")
        
        // Check if this is an error response (operator ERROR = 4)
        if bmapPacket.getOperatorId() == BmapPacket.OperatorIds.ERROR {
            print("[PairingModeEvent]: Pairing mode command failed (likely due to max connections)")
            // Notify that pairing mode is disabled (failed to enable)
            ConnectionsWindowController.shared.onPairingModeResponse(false)
            return
        }
        
        if let payload = bmapPacket.getPayload(), payload.count > 0 {
            let pairingModeEnabled = payload[0] == 1
            print("[PairingModeEvent]: Pairing mode is now \(pairingModeEnabled ? "enabled" : "disabled")")
            
            // Notify the connections window about the pairing mode state
            ConnectionsWindowController.shared.onPairingModeResponse(pairingModeEnabled)
        }
    }
}

private class InfoFunction: Function {
    
    static let id: Int8 = 5
    
    static func parsePacket(bmapPacket: BmapPacket, eventHandler: EventHandler) {
        print("[DeviceInfoEvent]: Device info response received")
        
        guard let payload = bmapPacket.getPayload(), payload.count >= 7 else {
            print("[DeviceInfoEvent]: Invalid payload length")
            return
        }
        
        // Parse according to wiki: [mac_addr_6_bytes] [flags] [optional_product_info] [device_name...]
        let macAddress = Array(payload[0..<6])
        let macString = macAddress.map { String(format: "%02X", UInt8(bitPattern: $0)) }.joined(separator: ":")
        let flags = UInt8(bitPattern: payload[6])
        
        let isConnected = (flags & 0x01) == 1
        let isLocalDevice = (flags & 0x02) == 2
        let isBoseProduct = (flags & 0x04) == 4
        
        print("[DeviceInfoEvent]: MAC: \(macString)")
        print("[DeviceInfoEvent]: Flags: 0x\(String(format: "%02X", flags))")
        print("[DeviceInfoEvent]: Connected: \(isConnected)")
        print("[DeviceInfoEvent]: Local Device: \(isLocalDevice)")
        print("[DeviceInfoEvent]: Bose Product: \(isBoseProduct)")
        
        // Extract device name if available
        var deviceName: String? = nil
        if payload.count > 7 {
            // Skip product info if it exists (varies by device type)
            var nameOffset = 7
            if isBoseProduct && payload.count > 8 {
                // Bose products may have additional product info
                nameOffset = 8
            }
            
            if nameOffset < payload.count {
                let nameBytes = Array(payload[nameOffset...])
                deviceName = String(bytes: nameBytes.map { UInt8(bitPattern: $0) }, encoding: .utf8)
                print("[DeviceInfoEvent]: Device Name: \(deviceName ?? "Unknown")")
            }
        }
        
        // Send the device info to the event handler
        let deviceInfo = DeviceInfo(
            macAddress: macString,
            isConnected: isConnected,
            isLocalDevice: isLocalDevice,
            isBoseProduct: isBoseProduct,
            deviceName: deviceName
        )
        
        if let deviceEventHandler = eventHandler as? DeviceManagementEventHandler {
            deviceEventHandler.onDeviceInfoReceived(deviceInfo)
        }
    }
}
