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

import IOBluetooth
import os.log

// Thread-safe wrapper for channel and device state
private class ConnectionState {
    private let queue = DispatchQueue(label: "com.noqcnolife.connectionState", attributes: .concurrent)
    private var _channel: IOBluetoothRFCOMMChannel?
    private var _device: IOBluetoothDevice?
    private var _productId: Int?
    private var _isConnecting: Bool = false
    
    var channel: IOBluetoothRFCOMMChannel? {
        get { queue.sync { _channel } }
        set { queue.async(flags: .barrier) { self._channel = newValue } }
    }
    
    var device: IOBluetoothDevice? {
        get { queue.sync { _device } }
        set { queue.async(flags: .barrier) { self._device = newValue } }
    }
    
    var productId: Int? {
        get { queue.sync { _productId } }
        set { queue.async(flags: .barrier) { self._productId = newValue } }
    }
    
    var isConnecting: Bool {
        get { queue.sync { _isConnecting } }
        set { queue.async(flags: .barrier) { self._isConnecting = newValue } }
    }
    
    func reset() {
        queue.async(flags: .barrier) {
            self._channel = nil
            self._device = nil
            self._productId = nil
            self._isConnecting = false
        }
    }
    
    func sendPacket(_ packet: [Int8]) -> IOReturn? {
        return queue.sync {
            guard let channel = _channel else { return nil }
            
            // Create a completely independent buffer for the packet
            let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: packet.count)
            defer { buffer.deallocate() }
            
            // Copy packet data to the buffer
            for i in 0..<packet.count {
                buffer[i] = packet[i]
            }
            
            return channel.writeSync(buffer, length: UInt16(packet.count))
        }
    }
}

class Bt {

    private let connectionState = ConnectionState()
    private var delegate: BluetoothDelegate
    private var disconnectBtUserNotification: IOBluetoothUserNotification?
    
    init(_ delegate: BluetoothDelegate) {
        self.delegate = delegate
    }
    
    func forceReconnect() {
        #if DEBUG
        print("[BT]: Force reconnect requested")
        #endif
        
        // Simply reset state and try to connect
        connectionState.reset()
        
        // Wait a moment then try to connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForConnectedDevices()
        }
    }
    
    func checkForConnectedDevices() {
        NSLog("[NoQCNoLife-BT]: Checking for already connected devices")
        NSLog("[NoQCNoLife-BT]: Current state - isConnecting: \(connectionState.isConnecting), device: \(connectionState.device != nil), channel: \(connectionState.channel != nil)")
        
        #if DEBUG
        print("[BT]: Checking for already connected devices")
        print("[BT]: Current state - isConnecting: \(connectionState.isConnecting), device: \(connectionState.device != nil), channel: \(connectionState.channel != nil)")
        #endif
        
        // Prevent multiple simultaneous connection attempts
        if connectionState.isConnecting {
            #if DEBUG
            print("[BT]: Already connecting, skipping check")
            #endif
            return
        }
        
        // If we think we're connected but don't have a channel, reset and try again
        if connectionState.device != nil && connectionState.channel == nil {
            #if DEBUG
            print("[BT]: Have device but no channel, resetting connection state")
            #endif
            connectionState.reset()
        }
        
        // If already connected with a valid channel, skip
        if connectionState.device != nil && connectionState.channel != nil {
            #if DEBUG
            print("[BT]: Already connected with valid channel, skipping check")
            #endif
            return
        }
        
        connectionState.isConnecting = true
        
        var device: IOBluetoothDevice!
        var productId: Int!
        
        if (findConnectedBoseDevice(connectedDevice: &device, productId: &productId)) {
            #if DEBUG
            print("[BT]: Found already connected Bose device with product ID: \(productId ?? 0)")
            #endif
            
            var channel: IOBluetoothRFCOMMChannel!
            if (!openConnection(connectedDevice: device, rfcommChannel: &channel)) {
                os_log("Failed to open rfcomm channel.", type: .error)
                #if DEBUG
                print("[BT]: Failed to open RFCOMM channel for device: \(device.name ?? "Unknown")")
                #endif
                connectionState.isConnecting = false
                return
            }
            
            // Set all connection state atomically
            connectionState.device = device
            connectionState.productId = productId
            connectionState.channel = channel
            connectionState.isConnecting = false
            
            NSLog("[NoQCNoLife-BT]: Successfully opened RFCOMM channel, notifying delegate")
            #if DEBUG
            print("[BT]: Successfully opened RFCOMM channel")
            #endif
            
            // Unregister any existing disconnect notification to prevent duplicates
            self.disconnectBtUserNotification?.unregister()
            self.disconnectBtUserNotification = device.register(forDisconnectNotification: self,
                                                               selector: #selector(Bt.onDisconnectDetected))
            
            // IMPORTANT: Notify the delegate that we're connected
            // This triggers the UI update
            self.delegate.onConnect()
        } else {
            #if DEBUG
            print("[BT]: No connected Bose device found")
            #endif
            connectionState.isConnecting = false
        }
    }
    
    func closeConnection() {
        let channel = connectionState.channel
        connectionState.reset()
        
        let result = channel?.close()
        if (result != nil && result != 0 ) {
            #if DEBUG
            print("[BT]: Warning - Failed to close connection, result: \(result!)")
            #endif
            // Don't assert in production, just log the error
            os_log("Failed to close connection, result: %d", type: .error, result!)
        }
        
        self.disconnectBtUserNotification?.unregister()
    }
    
    private func findConnectedBoseDevice(connectedDevice: inout IOBluetoothDevice!, productId: inout Int!) -> Bool {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() else {
            NSLog("[NoQCNoLife-BT]: No paired devices found")
            #if DEBUG
            print("[BT]: No paired devices found")
            #endif
            return false
        }
        
        NSLog("[NoQCNoLife-BT]: Found \(pairedDevices.count) paired devices")
        #if DEBUG
        print("[BT]: Found \(pairedDevices.count) paired devices")
        #endif
        
        for pairedDevice in pairedDevices {
            let pairedDevice = pairedDevice as! IOBluetoothDevice
            
            // Skip devices without valid addresses to avoid CoreBluetooth errors
            guard pairedDevice.addressString != nil else {
                #if DEBUG
                print("[BT]: Skipping device with no address")
                #endif
                continue
            }
            
            NSLog("[NoQCNoLife-BT]: Checking device: \(pairedDevice.name ?? "Unknown")")
            #if DEBUG
            print("[BT]: Checking device: \(pairedDevice.name ?? "Unknown")")
            #endif
            
            if (!pairedDevice.isConnected()) {
                NSLog("[NoQCNoLife-BT]:   - Device not connected")
                #if DEBUG
                print("[BT]:   - Not connected")
                #endif
                continue
            }
            
            #if DEBUG
            print("[BT]:   - Is connected, checking PnP info")
            #endif
            
            guard let pnpInfo = processPnPInfomation(pairedDevice) else {
                #if DEBUG
                print("[BT]:   - No PnP info available")
                #endif
                continue
            }
            
            #if DEBUG
            print("[BT]:   - Vendor ID: \(pnpInfo.venderId), Product ID: \(pnpInfo.productId)")
            #endif
            
            if (Bose.isSupportedBoseProduct(venderId: pnpInfo.venderId, productId: pnpInfo.productId)) {
                #if DEBUG
                print("[BT]:   - This is a supported Bose product!")
                #endif
                connectedDevice = pairedDevice
                productId = pnpInfo.productId
                return true
            } else {
                #if DEBUG
                print("[BT]:   - Not a supported Bose product")
                #endif
            }
        }
        
        return false
    }
    
    func getProductId() -> Int? {
        return connectionState.productId
    }
    
    @objc func onDisconnectDetected() {
        #if DEBUG
        print("[BT]: DisconnectDetected")
        print("[BT]: Cleaning up connection state")
        #endif
        
        // Only process disconnect if we actually have a connection
        // This prevents spurious disconnect notifications from affecting new connections
        guard connectionState.device != nil || connectionState.channel != nil else {
            #if DEBUG
            print("[BT]: Ignoring disconnect notification - no active connection")
            #endif
            return
        }
        
        self.closeConnection()
        self.delegate.onDisconnect()
        
        // Commented out auto-reconnect to prevent potential issues
        // User can reconnect by clicking the menu
        /*
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            #if DEBUG
            print("[BT]: Attempting to reconnect after disconnect")
            #endif
            self?.checkForConnectedDevices()
        }
        */
    }
    
    
    @objc func onNewConnectionDetected() {
        #if DEBUG
        print("[BT]: NewConnectionDetected")
        #endif
        
        // Prevent multiple simultaneous connection attempts
        if connectionState.isConnecting || connectionState.device != nil {
            return
        }
        
        connectionState.isConnecting = true
        
        var device: IOBluetoothDevice!
        var productId: Int!
        
        if (!findConnectedBoseDevice(connectedDevice: &device, productId: &productId)) {
            #if DEBUG
            print("Connected bose device is not found.")
            #endif
            connectionState.isConnecting = false
            return
        }
        
        var channel: IOBluetoothRFCOMMChannel!
        if (!openConnection(connectedDevice: device, rfcommChannel: &channel)) {
            os_log("Failed to open rfcomm channel.", type: .error)
            connectionState.isConnecting = false
            return
        }
        
        // Set all connection state atomically
        connectionState.device = device
        connectionState.productId = productId
        connectionState.channel = channel
        connectionState.isConnecting = false
        
        // Unregister any existing disconnect notification to prevent duplicates
        self.disconnectBtUserNotification?.unregister()
        self.disconnectBtUserNotification = device.register(forDisconnectNotification: self,
                                                           selector: #selector(Bt.onDisconnectDetected))
        
        // IMPORTANT: Notify the delegate that we're connected
        // This was missing when connection happens through onNewConnectionDetected
        NSLog("[NoQCNoLife-BT]: Connection established through onNewConnectionDetected, notifying delegate")
        self.delegate.onConnect()
    }
    
    private func openConnection(connectedDevice: IOBluetoothDevice!, rfcommChannel: inout IOBluetoothRFCOMMChannel!) -> Bool {
        
        guard connectedDevice != nil else {
            #if DEBUG
            print("[BT]: ERROR - connectedDevice is nil in openConnection")
            #endif
            return false
        }
        
        #if DEBUG
        print("[BT]: Opening RFCOMM connection to: \(connectedDevice.name ?? "Unknown")")
        #endif
        
        var rfcommChannelId: BluetoothRFCOMMChannelID = 0
        
        let serialPortServiceRecode = connectedDevice.getServiceRecord(for: IOBluetoothSDPUUID(uuid16: 0x1101))
        if (serialPortServiceRecode == nil) {
            #if DEBUG
            print("[BT]: ERROR - No serial port service record found")
            #endif
            return false
        }
        
        if (serialPortServiceRecode!.getRFCOMMChannelID(&rfcommChannelId) != kIOReturnSuccess) {
            #if DEBUG
            print("[BT]: ERROR - Failed to get RFCOMM channel ID")
            #endif
            return false
        }
        
        #if DEBUG
        print("[BT]: Got RFCOMM channel ID: \(rfcommChannelId)")
        #endif
        
        let result = connectedDevice.openRFCOMMChannelSync(&rfcommChannel,
                                                  withChannelID: rfcommChannelId,
                                                  delegate: self)
        if (result != kIOReturnSuccess) {
            #if DEBUG
            print("[BT]: ERROR - Failed to open RFCOMM channel, result: \(result)")
            #endif
            return false
        }
        
        #if DEBUG
        print("[BT]: Successfully opened RFCOMM channel")
        #endif
        
        return true
    }
    
    private func processPnPInfomation (_ device: IOBluetoothDevice) -> (venderId:Int, productId: Int)? {
        
        let uuid: BluetoothSDPUUID16 = 0x1200 // PnPInformation
        let spdUuid: IOBluetoothSDPUUID = IOBluetoothSDPUUID(uuid16: uuid)
        
        guard let serviceRecode = device.getServiceRecord(for: spdUuid) else {
            return nil
        }
        
        guard let venderId = serviceRecode.getAttributeDataElement(0x0201)?.getNumberValue() else {
            return nil
        }
//        print("venderId:\(venderId)")
        
        guard let productId = serviceRecode.getAttributeDataElement(0x0202)?.getNumberValue() else {
            return nil
        }
//        print("productId: \(productId)")
        
        /*guard let version = serviceRecode.getAttributeDataElement(0x0203)?.getNumberValue() else {
            return nil
        }
        print("version: \(version)")*/
        
        return (venderId.intValue, productId.intValue)
    }
    
    func sendGetAnrModePacket () -> Bool {
        guard let packet = Bose.generateGetAnrModePacket() else {
            os_log("Failed to generate getAnrModePacket.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendGetBassControlPacket () -> Bool {
        guard let packet = Bose.generateGetBassControlPacket() else {
            os_log("Failed to generate getBassControlPacket.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendGetBatteryLevelPacket () -> Bool {
        guard let packet = Bose.generateGetBatteryLevelPacket() else {
            os_log("Failed to generate getBatteryLevelPacket.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    private func sendPacketSync(_ packet: [Int8]) -> Bool {
        let result = connectionState.sendPacket(packet)
        
        if (result == nil || result != kIOReturnSuccess) {
            return false
        }
        #if DEBUG
        print("[Sent]: \(packet)")
        #endif
        return true
    }
    
    func sendSetGetAnrModePacket(_ anrMode: Bose.AnrMode) -> Bool {
        guard let packet = Bose.generateSetGetAnrModePacket(anrMode) else {
            os_log("Failed to generate setGetAnrPacket.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendSetGetBassControlPacket(_ step: Int) -> Bool {
        guard let packet = Bose.generateSetGetBassControlPacket(step) else {
            os_log("Failed to generate setGetBassControl packet.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
}

extension Bt: IOBluetoothRFCOMMChannelDelegate {
    
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        NSLog("[NoQCNoLife-BT]: RFCOMM channel closed")
        #if DEBUG
        print("[BT]: rfcommChannelClosed")
        #endif
        
        // Reset connection state
        connectionState.reset()
        
        // Notify delegate that we're disconnected
        self.delegate.onDisconnect()
        
        // Also unregister the disconnect notification if it exists
        self.disconnectBtUserNotification?.unregister()
        self.disconnectBtUserNotification = nil
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                           data dataPointer: UnsafeMutableRawPointer!,
                           length dataLength: Int) {
        //        print("rfcommChannelData")
        
        // Validate input parameters
        guard dataPointer != nil, dataLength > 0 else {
            os_log("Invalid data received: nil pointer or zero length", type: .error)
            return
        }
        
        // Additional safety check for reasonable data length
        guard dataLength < 10000 else {
            os_log("Received unusually large data packet: %d bytes", type: .error, dataLength)
            return
        }
        
        let buffer = UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: Int8.self), count: dataLength)
        let array = Array(buffer)
        
        #if DEBUG
        print("[Received]: \(array) (length: \(dataLength))")
        #endif
        
        // Process multiple packets that might be in the same transmission
        var offset = 0
        while offset < array.count {
            // Check if we have at least a header (4 bytes)
            if offset + 4 > array.count {
                break
            }
            
            // Get the payload length from the 4th byte
            let payloadLength = Int(UInt8(bitPattern: array[offset + 3]))
            let packetLength = 4 + payloadLength
            
            // Check if we have a complete packet
            if offset + packetLength > array.count {
                os_log("Incomplete packet at offset %d, expected %d bytes but only %d remaining",
                      type: .error, offset, packetLength, array.count - offset)
                break
            }
            
            // Extract single packet
            var singlePacket = Array(array[offset..<(offset + packetLength)])
            
            #if DEBUG
            print("[Processing packet]: \(singlePacket)")
            #endif
            
            // Parse the single packet
            Bose.parsePacket(packet: &singlePacket, eventHandler: self.delegate)
            
            // Move to next packet
            offset += packetLength
        }
    }
    
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                                   status error: IOReturn) {
//        print("rfcommChannelOpenComplete")
        // [重要] BmapVersionを取得しないと、一切データを送ってこない。
        guard let packet = Bose.generateGetBmapVersionPacket() else {
            assert(false, "Failed to generate getBmapVersionPacket @ Bt::rfcommChannelOpenComplete()")
            os_log("Failed to generate getBmapVersionPacket.", type: .error)
            self.closeConnection()
            self.delegate.bmapVersionEvent(nil)
            return
        }
        
        if (self.sendPacketSync(packet) == false) {
            self.closeConnection()
            self.delegate.bmapVersionEvent(nil)
        }
    }
    
    /*func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                                    refcon: UnsafeMutableRawPointer!,
                                    status error: IOReturn) {
        print("rfcommChannelWriteComplete")
    }*/
}

protocol  BluetoothDelegate: EventHandler {
    func onConnect()
    func onDisconnect()
}

extension BluetoothDelegate {
    func bmapVersionEvent(_ version: String?) {
//        print("[BmapVersionEvent]: \(version)")
        if (version != nil) {
            self.onConnect()
        } else {
            self.onDisconnect()
        }
    }
}
