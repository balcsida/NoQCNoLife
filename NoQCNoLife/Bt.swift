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
            guard let channel = _channel else {
                #if DEBUG
                print("[BT]: ERROR - No channel available for sending packet")
                #endif
                return nil
            }
            
            #if DEBUG
            print("[BT]: Sending packet on channel - isOpen: \(channel.isOpen())")
            #endif
            
            // Create a completely independent buffer for the packet
            let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: packet.count)
            defer { buffer.deallocate() }
            
            // Copy packet data to the buffer
            for i in 0..<packet.count {
                buffer[i] = packet[i]
            }
            
            let result = channel.writeSync(buffer, length: UInt16(packet.count))
            
            #if DEBUG
            if result != kIOReturnSuccess {
                print("[BT]: ERROR - Failed to write to channel, result: \(result)")
            }
            #endif
            
            return result
        }
    }
}

class Bt {

    private let connectionState = ConnectionState()
    private var delegate: BluetoothDelegate
    private var disconnectBtUserNotification: IOBluetoothUserNotification?
    private var bmapVersionRequested = false
    private var lastDeviceCheckTime: Date = Date.distantPast
    private let deviceCheckCooldown: TimeInterval = 0.5 // Minimum 500ms between checks
    
    init(_ delegate: BluetoothDelegate) {
        self.delegate = delegate
    }
    
    func forceReconnect() {
        #if DEBUG
        print("[BT]: Force reconnect requested")
        #endif
        
        // Simply reset state and try to connect
        connectionState.reset()
        bmapVersionRequested = false // Reset the flag for next connection
        
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
            bmapVersionRequested = false
        }
        
        // If already connected with a valid channel, verify it's still active
        if let channel = connectionState.channel, connectionState.device != nil {
            if channel.isOpen() {
                #if DEBUG
                print("[BT]: Already connected with valid open channel, skipping check")
                #endif
                return
            } else {
                #if DEBUG
                print("[BT]: Channel exists but is closed, resetting connection state")
                #endif
                connectionState.reset()
                bmapVersionRequested = false
            }
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
        bmapVersionRequested = false  // Reset the flag for next connection
        
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
        
        // Add cooldown check to prevent excessive polling
        let now = Date()
        if now.timeIntervalSince(lastDeviceCheckTime) < deviceCheckCooldown {
            #if DEBUG
            print("[BT]: Device check on cooldown, skipping")
            #endif
            return false
        }
        lastDeviceCheckTime = now
        
        // Filter to connected devices - simplified approach to avoid race conditions
        let connectedDevices = pairedDevices.compactMap { device -> IOBluetoothDevice? in
            guard let btDevice = device as? IOBluetoothDevice,
                  btDevice.addressString != nil else { return nil }
            
            // Direct connection check - this is the safest approach
            // The previous timeout logic was causing race conditions
            return btDevice.isConnected() ? btDevice : nil
        }
        
        NSLog("[NoQCNoLife-BT]: Found \(connectedDevices.count) connected devices")
        #if DEBUG
        print("[BT]: Found \(connectedDevices.count) connected devices")
        #endif
        
        // Now check only connected devices for Bose products
        for pairedDevice in connectedDevices {
            NSLog("[NoQCNoLife-BT]: Checking connected device: \(pairedDevice.name ?? "Unknown")")
            #if DEBUG
            print("[BT]: Checking connected device: \(pairedDevice.name ?? "Unknown")")
            #endif
            
            // Get PnP info directly - timeout was causing issues
            let pnpInfo = processPnPInfomation(pairedDevice)
            
            guard let info = pnpInfo else {
                #if DEBUG
                print("[BT]:   - No PnP info available or timeout")
                #endif
                continue
            }
            
            #if DEBUG
            print("[BT]:   - Vendor ID: \(info.venderId), Product ID: \(info.productId)")
            #endif
            
            if (Bose.isSupportedBoseProduct(venderId: info.venderId, productId: info.productId)) {
                #if DEBUG
                print("[BT]:   - This is a supported Bose product!")
                #endif
                connectedDevice = pairedDevice
                productId = info.productId
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
        print("[BT]: DisconnectDetected - device: \(connectionState.device != nil), channel: \(connectionState.channel != nil)")
        print("[BT]: Cleaning up connection state")
        #endif
        
        // Only process disconnect if we actually have a connection
        // This prevents spurious disconnect notifications from affecting new connections
        guard connectionState.device != nil && connectionState.channel != nil else {
            #if DEBUG
            print("[BT]: Ignoring disconnect notification - no active connection or incomplete connection")
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
        
        // Set device and productId BEFORE opening channel
        // This prevents disconnect detection from closing the channel prematurely
        connectionState.device = device
        connectionState.productId = productId
        
        var channel: IOBluetoothRFCOMMChannel!
        if (!openConnection(connectedDevice: device, rfcommChannel: &channel)) {
            os_log("Failed to open rfcomm channel.", type: .error)
            connectionState.reset()  // Reset on failure
            return
        }
        
        // Set the channel after successful opening
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
        print("[BT]: Device connection state: \(connectedDevice.isConnected())")
        #endif
        
        
        // Add a small delay to allow any previous connections to fully close
        usleep(100000) // Wait 100ms
        
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
        
        // Try the sync version first - it seems more reliable even with errors
        let result = connectedDevice.openRFCOMMChannelSync(&rfcommChannel,
                                                  withChannelID: rfcommChannelId,
                                                  delegate: self)
        if (result != kIOReturnSuccess) {
            #if DEBUG
            print("[BT]: Sync RFCOMM channel open returned error: \(result)")
            #endif
            
            // Even if the sync call fails, the channel might still be created
            // Check if we have a valid channel anyway
            if rfcommChannel == nil {
                #if DEBUG
                print("[BT]: No channel created, trying async as fallback")
                #endif
                
                // Try async as a fallback
                let asyncResult = connectedDevice.openRFCOMMChannelAsync(&rfcommChannel,
                                                                         withChannelID: rfcommChannelId,
                                                                         delegate: self)
                if asyncResult == kIOReturnSuccess {
                    #if DEBUG
                    print("[BT]: Async RFCOMM channel open initiated successfully")
                    #endif
                    
                    // Set up a fallback timer in case rfcommChannelOpenComplete is never called
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        guard let self = self else { return }
                        
                        #if DEBUG
                        print("[BT]: Fallback timer fired - checking if BMAP version was sent")
                        #endif
                        
                        // If we still haven't sent the BMAP version packet after 3 seconds,
                        // try to send it anyway as a fallback
                        if !self.bmapVersionRequested, let channel = self.connectionState.channel {
                            #if DEBUG
                            print("[BT]: rfcommChannelOpenComplete never called, attempting fallback BMAP version send")
                            print("[BT]: Channel state - exists: true, isOpen: \(channel.isOpen())")
                            #endif
                            
                            // Force send the BMAP version packet
                            self.sendBmapVersionPacket()
                        }
                    }
                    
                    return true
                } else {
                    #if DEBUG
                    print("[BT]: ERROR - Both sync and async RFCOMM channel open failed")
                    #endif
                    return false
                }
            } else {
                #if DEBUG
                print("[BT]: Sync call failed but channel was created, proceeding")
                #endif
            }
        } else {
            #if DEBUG
            print("[BT]: Sync RFCOMM channel open succeeded")
            #endif
        }
        
        #if DEBUG
        print("[BT]: Successfully opened RFCOMM channel")
        print("[BT]: Channel is open: \(rfcommChannel.isOpen())")
        print("[BT]: Channel MTU: \(rfcommChannel.getMTU())")
        #endif
        
        // Explicitly set delegate again to ensure it's properly configured
        rfcommChannel.setDelegate(self)
        
        #if DEBUG
        print("[BT]: After setDelegate - delegate set")
        #endif
        
        // Manually send BMAP version packet since rfcommChannelOpenComplete might not be called
        // if the channel opened synchronously
        if rfcommChannel.isOpen() && !bmapVersionRequested {
            #if DEBUG
            print("[BT]: Channel is already open, sending BMAP version packet immediately")
            #endif
            sendBmapVersionPacket()
        } else if !bmapVersionRequested {
            #if DEBUG
            print("[BT]: Channel not yet open (isOpen=\(rfcommChannel.isOpen())), setting up delayed send")
            #endif
            
            // Set up a delayed attempt to send the BMAP version packet
            // This covers cases where the channel reports as closed but might work anyway
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, !self.bmapVersionRequested else { return }
                
                #if DEBUG
                print("[BT]: Delayed BMAP version send attempt")
                if let channel = self.connectionState.channel {
                    print("[BT]: Channel state after delay: isOpen=\(channel.isOpen()), MTU=\(channel.getMTU())")
                }
                #endif
                
                // Try sending even if the channel reports as closed
                self.sendBmapVersionPacket()
            }
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
    
    func sendListDevicesPacket() -> Bool {
        guard let packet = DeviceManagementFunctionBlock.generateListDevicesPacket() else {
            os_log("Failed to generate list devices packet.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendConnectDevicePacket(macAddress: [UInt8]) -> Bool {
        guard let packet = DeviceManagementFunctionBlock.generateConnectDevicePacket(macAddress: macAddress) else {
            os_log("Failed to generate connect device packet.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendDisconnectDevicePacket(macAddress: [UInt8]) -> Bool {
        guard let packet = DeviceManagementFunctionBlock.generateDisconnectDevicePacket(macAddress: macAddress) else {
            os_log("Failed to generate disconnect device packet.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendRemoveDevicePacket(macAddress: [UInt8]) -> Bool {
        guard let packet = DeviceManagementFunctionBlock.generateRemoveDevicePacket(macAddress: macAddress) else {
            os_log("Failed to generate remove device packet.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendEnterPairingModePacket() -> Bool {
        guard let packet = DeviceManagementFunctionBlock.generateEnterPairingModePacket() else {
            os_log("Failed to generate enter pairing mode packet.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendExitPairingModePacket() -> Bool {
        guard let packet = DeviceManagementFunctionBlock.generateExitPairingModePacket() else {
            os_log("Failed to generate exit pairing mode packet.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendDeviceInfoPacket(macAddress: [UInt8]) -> Bool {
        guard let packet = DeviceManagementFunctionBlock.generateDeviceInfoPacket(macAddress: macAddress) else {
            os_log("Failed to generate device info packet.", type: .error)
            return false
        }
        return sendPacketSync(packet)
    }
    
    func sendRawPacket(_ packet: [Int8]) -> Bool {
        return sendPacketSync(packet)
    }
    
    private func sendBmapVersionPacket() {
        bmapVersionRequested = true
        
        guard let packet = Bose.generateGetBmapVersionPacket() else {
            #if DEBUG
            print("[BT]: ERROR - Failed to generate BMAP version packet")
            #endif
            closeConnection()
            delegate.bmapVersionEvent(nil)
            return
        }
        
        #if DEBUG
        print("[BT]: Sending BMAP version packet: \(packet)")
        if let channel = connectionState.channel {
            print("[BT]: Channel state: isOpen = \(channel.isOpen()), MTU = \(channel.getMTU())")
        }
        #endif
        
        // Try to send the packet - this might work even if the channel reports as closed
        let sendResult = sendPacketSync(packet)
        
        #if DEBUG
        print("[BT]: BMAP version packet send result: \(sendResult)")
        #endif
        
        if !sendResult {
            #if DEBUG
            print("[BT]: First attempt to send BMAP version packet failed, trying one more time after delay")
            #endif
            
            // Sometimes the channel needs a moment, try once more after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                #if DEBUG
                print("[BT]: Retrying BMAP version packet send")
                #endif
                
                if !self.sendPacketSync(packet) {
                    #if DEBUG
                    print("[BT]: ERROR - Failed to send BMAP version packet after retry")
                    #endif
                    self.closeConnection()
                    self.delegate.bmapVersionEvent(nil)
                } else {
                    #if DEBUG
                    print("[BT]: Successfully sent BMAP version packet on retry")
                    #endif
                }
            }
        } else {
            #if DEBUG
            print("[BT]: Successfully sent BMAP version packet")
            #endif
        }
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
        bmapVersionRequested = false  // Reset the flag for next connection
        
        // Notify delegate that we're disconnected
        self.delegate.onDisconnect()
        
        // Also unregister the disconnect notification if it exists
        self.disconnectBtUserNotification?.unregister()
        self.disconnectBtUserNotification = nil
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                           data dataPointer: UnsafeMutableRawPointer!,
                           length dataLength: Int) {
        #if DEBUG
        print("[BT]: rfcommChannelData called with \(dataLength) bytes")
        #endif
        
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
        #if DEBUG
        print("[BT]: rfcommChannelOpenComplete called, status: \(error)")
        print("[BT]: Channel in callback: \(rfcommChannel != nil), isOpen: \(rfcommChannel?.isOpen() ?? false)")
        #endif
        
        // Prevent sending BMAP version packet multiple times if callback is triggered multiple times
        if bmapVersionRequested {
            #if DEBUG
            print("[BT]: BMAP version already requested, skipping duplicate")
            #endif
            return
        }
        
        // [重要] BmapVersionを取得しないと、一切データを送ってこない。
        #if DEBUG
        print("[BT]: Channel opened, sending BMAP version packet via callback")
        #endif
        sendBmapVersionPacket()
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
        // Don't call onConnect() here as it's already called when connection is established
        // This was causing duplicate menu items
        if (version == nil) {
            self.onDisconnect()
        }
    }
}
