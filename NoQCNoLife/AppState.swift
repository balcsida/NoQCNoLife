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
class AppState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectedProduct: Bose.Products?
    @Published var batteryLevel: Int?
    @Published var noiseCancelMode: Bose.AnrMode?
    @Published var bassControlStep: Int?
    
    var supportsNoiseCancellation: Bool {
        guard let product = connectedProduct else { return false }
        switch product {
        case .WOLFCASTLE, .BAYWOLF:
            return true
        case .KLEOS:
            return false
        }
    }
    
    var supportsBassControl: Bool {
        guard let product = connectedProduct else { return false }
        switch product {
        case .KLEOS:
            return true
        case .WOLFCASTLE, .BAYWOLF:
            return false
        }
    }
    
    func connected(to product: Bose.Products) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedProduct = product
        }
    }
    
    func disconnected() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedProduct = nil
            self.batteryLevel = nil
            self.noiseCancelMode = nil
            self.bassControlStep = nil
        }
    }
    
    // These methods only update the UI state, they don't trigger commands
    func updateBatteryLevel(_ level: Int?) {
        DispatchQueue.main.async {
            self.batteryLevel = level
        }
    }
    
    func updateNoiseCancelMode(_ mode: Bose.AnrMode?) {
        DispatchQueue.main.async {
            self.noiseCancelMode = mode
        }
    }
    
    func updateBassControlStep(_ step: Int?) {
        DispatchQueue.main.async {
            self.bassControlStep = step
        }
    }
}