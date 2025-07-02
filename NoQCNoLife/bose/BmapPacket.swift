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

import os.log

class BmapPacket {
    
    private var a: Array<Int8>!
    private var b: Int8!
    private var c: Int8!
    private var d: Int8!
    private var e: Int8!
    private var f: Int8!
    private var g: Array<Int8>!
    private var isValid: Bool = false
    
    enum FunctionBlockIds: Int8 {
        case PRODUCT_INFO,
        SETTINGS,
        STATUS,
        FIRMWARE_UPDATE,
        DEVICE_MANAGEMENT,
        AUDIO_MANAGEMENT,
        CALL_MANAGEMENT,
        CONTROL,
        DEBUG,
        NOTIFICATION,
        RESERVED_BOSEBUILD_1,
        RESERVED_BOSEBUILD_2,
        HEARING_ASSISTANCE,
        DATA_COLLECTION,
        HEART_RATE,
        UNDEFINED_1,
        VPA
        /*
         FIRMWARE_UPDATE = new FUNCTION_BLOCK("FIRMWARE_UPDATE", 4, 3, FirmwareUpdatePackets.class);
         DEVICE_MANAGEMENT = new FUNCTION_BLOCK("DEVICE_MANAGEMENT", 5, 4, DeviceManagementPackets.class);
         AUDIO_MANAGEMENT = new FUNCTION_BLOCK("AUDIO_MANAGEMENT", 6, 5, AudioManagementPackets.class);
         CALL_MANAGEMENT = new FUNCTION_BLOCK("CALL_MANAGEMENT", 7, 6);
         CONTROL = new FUNCTION_BLOCK("CONTROL", 8, 7, ControlPackets.class);
         DEBUG = new FUNCTION_BLOCK("DEBUG", 9, 8);
         NOTIFICATION = new FUNCTION_BLOCK("NOTIFICATION", 10, 9, NotificationPackets.class);
         RESERVED_BOSEBUILD_1 = new FUNCTION_BLOCK("RESERVED_BOSEBUILD_1", 11, 10);
         RESERVED_BOSEBUILD_2 = new FUNCTION_BLOCK("RESERVED_BOSEBUILD_2", 12, 11);
         HEARING_ASSISTANCE = new FUNCTION_BLOCK("HEARING_ASSISTANCE", 13, 12, HearingAssistancePackets.class);
         DATA_COLLECTION = new FUNCTION_BLOCK("DATA_COLLECTION", 14, 13, DataCollectionPackets.class);
         HEART_RATE = new FUNCTION_BLOCK("HEART_RATE", 15, 14, HeartRatePackets.class);
         VPA = new FUNCTION_BLOCK("VPA", 16, 16, VoicePersonalAssistantPackets.class);
         $VALUES = new FUNCTION_BLOCK[] {
         UNKNOWN, PRODUCT_INFO, SETTINGS, STATUS, FIRMWARE_UPDATE, DEVICE_MANAGEMENT, AUDIO_MANAGEMENT, CALL_MANAGEMENT, CONTROL, DEBUG,
         NOTIFICATION, RESERVED_BOSEBUILD_1, RESERVED_BOSEBUILD_2, HEARING_ASSISTANCE, DATA_COLLECTION, HEART_RATE, VPA };
         */
    }

    enum OperatorIds: Int8 {
        case SET, GET, SET_GET, STATUS, ERROR, START, RESULT, PROCESSING
        /*
         GET = new OPERATOR("GET", 2, 1);
         SET_GET = new OPERATOR("SET_GET", 3, 2);
         STATUS = new OPERATOR("STATUS", 4, 3, BmapPacket.c.IN);
         ERROR = new OPERATOR("ERROR", 5, 4, BmapPacket.c.IN);
         START = new OPERATOR("START", 6, 5, BmapPacket.c.IN);
         RESULT = new OPERATOR("RESULT", 7, 6, BmapPacket.c.IN);
         PROCESSING = new OPERATOR("PROCESSING", 8, 7, BmapPacket.c.IN);
         $VALUES = new OPERATOR[] { UNKNOWN, SET, GET, SET_GET, STATUS, ERROR, START, RESULT, PROCESSING };
        */
        
        func toString() -> String {
            switch self {
            case .SET: return "Set"
            case .GET: return "Get"
            case .SET_GET: return "SetGet"
            case .STATUS: return "Status"
            case .ERROR: return "Error"
            case .START: return "Start"
            case .RESULT: return "Result"
            case .PROCESSING: return "Processing"
            }
        }
    }
    
    init?(_ packet: inout [Int8]) {
        if (packet.count < 4) {
            os_log("Failed to spawn BmapPacket: Invalid packet size (%d bytes, minimum 4 required)", type: .error, packet.count)
            return nil
        }
        
        self.a = packet
        self.b = packet[0]
        self.c = packet[1]
        self.d = packet[2] >> 6
        self.e = (packet[2] >> 4) & 0x3
        self.f = packet[2] & 0xF
        
        let payloadLen: Int = Int(UInt8(bitPattern: Int8(packet[3])))
        
        // Check if the payload length is reasonable
        if payloadLen < 0 || payloadLen > 1024 {
            os_log("Failed to spawn BmapPacket: Unreasonable payload length (%d)", type: .error, payloadLen)
            return nil
        }
        
        if (packet.count != 4 + payloadLen) {
            os_log("Failed to spawn BmapPacket: Invalid payload. Expected %d bytes, got %d bytes", type: .error, 4 + payloadLen, packet.count)
            #if DEBUG
            print("Packet header: functionBlock=\(self.b), function=\(self.c), deviceId=\(self.d), port=\(self.e), operator=\(self.f), declaredPayloadLen=\(payloadLen)")
            print("Raw packet: \(packet)")
            #endif
            return nil
        }
        
        if payloadLen > 0 {
            self.g = Array(packet[4..<(4 + payloadLen)])
        } else {
            self.g = []
        }
        
        self.isValid = true
    }
    
    init(functionBlockId: BmapPacket.FunctionBlockIds, functionId: Int8, operatorId: BmapPacket.OperatorIds,
         deviceId: Int8, port: Int8, payload: [Int8]) {
        self.b = functionBlockId.rawValue
        self.c = functionId
        self.d = deviceId
        self.e = port
        self.f = operatorId.rawValue
        self.g = payload
        
        self.build()
        self.isValid = true
    }
    
    func build() {
        if (self.b == nil || self.c == nil || self.d == nil || self.e == nil || self.f == nil || self.g == nil) {
            os_log("Failed to build bmapPacket - missing required fields", type: .error)
            self.reset()
            return
        }
        
        self.a = Array<Int8>(repeating: 0, count: self.g.count + 4)
        self.a[0] = self.b
        self.a[1] = self.c
        self.a[2] = (self.d << 6 | self.e << 4 | self.f)
        self.a[3] = Int8(self.g.count)
        if (self.g.count > 0) {
            self.a.replaceSubrange(4...(self.a.count - 1), with: self.g)
        }
    }
    
    func getPacket() -> [Int8]? {
        return self.isValid ? self.a : nil
    }
    
    func getFunctionBlockId() -> BmapPacket.FunctionBlockIds? {
        return self.b == nil ? nil : BmapPacket.FunctionBlockIds(rawValue: self.b)
    }
    
    func getFunctionId() -> Int8? {
        return self.c
    }
    
    func getOperatorId() -> BmapPacket.OperatorIds? {
        return self.f == nil ? nil : BmapPacket.OperatorIds.init(rawValue: self.f)
    }
    
    func getPayload() ->  [Int8]? {
        return self.g
    }
    
    func toString() -> String {
        return String("BmapPacket{functionBlock=\(String(describing: self.b)), function=\(String(describing: self.c)), deviceId=\(String(describing: self.d)), port=\(String(describing: self.e)), operator=\(String(describing: self.f)), dataPayload=\(String(describing: self.g)), packet=\(String(describing: self.a))}")
    }
    
    func reset() {
        self.a = nil
        self.b = nil
        self.c = nil
        self.d = nil
        self.e = nil
        self.f = nil
        self.g = nil
        self.isValid = false
    }
}
