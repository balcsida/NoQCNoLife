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
    
    func reset() {
        queue.async(flags: .barrier) {
            self._channel = nil
            self._device = nil
            self._productId = nil
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
        
        // Check for already connected devices after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForConnectedDevices()
        }
    }
    
    func checkForConnectedDevices() {
        #if DEBUG
        print("[BT]: Checking for already connected devices")
        #endif
        
        if (connectionState.device != nil) {
            return
        }
        
        var device: IOBluetoothDevice!
        var productId: Int!
        
        if (findConnectedBoseDevice(connectedDevice: &device, productId: &productId)) {
            #if DEBUG
            print("[BT]: Found already connected Bose device")
            #endif
            
            var channel: IOBluetoothRFCOMMChannel!
            if (!openConnection(connectedDevice: device, rfcommChannel: &channel)) {
                os_log("Failed to open rfcomm channel.", type: .error)
                return
            }
            
            // Set all connection state atomically
            connectionState.device = device
            connectionState.productId = productId
            connectionState.channel = channel
            
            self.disconnectBtUserNotification = device.register(forDisconnectNotification: self,
                                                               selector: #selector(Bt.onDisconnectDetected))
        }
    }
    
    func closeConnection() {
        let channel = connectionState.channel
        connectionState.reset()
        
        let result = channel?.close()
        if (result != nil && result != 0 ) {
            assert(false, "Failed to close connection.")
        }
        
        self.disconnectBtUserNotification?.unregister()
    }
    
    private func findConnectedBoseDevice(connectedDevice: inout IOBluetoothDevice!, productId: inout Int!) -> Bool {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() else {
            return false
        }
        
        for pairedDevice in pairedDevices {
            let pairedDevice = pairedDevice as! IOBluetoothDevice
            if (!pairedDevice.isConnected()) {
                continue
            }
            
            guard let pnpInfo = processPnPInfomation(pairedDevice) else {
                continue
            }
            
            if (Bose.isSupportedBoseProduct(venderId: pnpInfo.venderId, productId: pnpInfo.productId)) {
                connectedDevice = pairedDevice
                productId = pnpInfo.productId
                return true
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
        #endif
        self.closeConnection()
        self.delegate.onDisconnect()
    }
    
    
    @objc func onNewConnectionDetected() {
        #if DEBUG
        print("[BT]: NewConnectionDetected")
        #endif
        if (connectionState.device != nil) {
            return
        }
        
        var device: IOBluetoothDevice!
        var productId: Int!
        
        if (!findConnectedBoseDevice(connectedDevice: &device, productId: &productId)) {
            #if DEBUG
            print("Connected bose device is not found.")
            #endif
            return
        }
        
        var channel: IOBluetoothRFCOMMChannel!
        if (!openConnection(connectedDevice: device, rfcommChannel: &channel)) {
            os_log("Failed to open rfcomm channel.", type: .error)
            return
        }
        
        // Set all connection state atomically
        connectionState.device = device
        connectionState.productId = productId
        connectionState.channel = channel
        
        self.disconnectBtUserNotification = device.register(forDisconnectNotification: self,
                                                           selector: #selector(Bt.onDisconnectDetected))
    }
    
    private func openConnection(connectedDevice: IOBluetoothDevice!, rfcommChannel: inout IOBluetoothRFCOMMChannel!) -> Bool {
        
        assert(connectedDevice != nil, "connectedDevice == nil")
        
        var rfcommChannelId: BluetoothRFCOMMChannelID = 0
        
        let serialPortServiceRecode = connectedDevice.getServiceRecord(for: IOBluetoothSDPUUID(uuid16: 0x1101))
        if (serialPortServiceRecode == nil) {
            return false
        }
        
        if (serialPortServiceRecode!.getRFCOMMChannelID(&rfcommChannelId) != kIOReturnSuccess) {
            return false
        }
        
        if (connectedDevice.openRFCOMMChannelSync(&rfcommChannel,
                                                  withChannelID: rfcommChannelId,
                                                  delegate: self) != kIOReturnSuccess) {
            return false
        }
        
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
//        print("rfcommChannelClosed")
        connectionState.reset()
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
        var array = Array(buffer)
        
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
