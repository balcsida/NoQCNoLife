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
import SwiftUI
import IOBluetooth
import os.log

@MainActor
class BluetoothManager {
    static let shared = BluetoothManager()
    var bt: Bt?
    
    private init() {}
    
    func setBluetooth(_ bluetooth: Bt) {
        self.bt = bluetooth
    }
}

// This file previously contained a duplicate SwiftUIAppDelegate class
// which was causing conflicts with the main AppDelegate.swift
// The functionality has been consolidated into AppDelegate.swift