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
class SwiftUIConnectionsWindowController: NSWindowController {
    static let shared = SwiftUIConnectionsWindowController()
    
    private let viewModel = ConnectionsViewModel()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.title = "Device Connections"
        window.center()
        setupContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupContent() {
        guard let window = self.window else { return }
        
        let contentView = NSHostingController(rootView: 
            ConnectionsView()
                .environmentObject(viewModel)
        )
        
        window.contentViewController = contentView
    }
    
    func showWindow() {
        viewModel.refreshDevices()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func didReceiveDeviceList(_ devices: [BosePairedDevice]) {
        viewModel.didReceiveDeviceList(devices)
    }
    
    func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        viewModel.onDeviceInfoReceived(deviceInfo)
    }
    
    func onPairingModeResponse(_ isEnabled: Bool) {
        viewModel.onPairingModeResponse(isEnabled)
    }
}