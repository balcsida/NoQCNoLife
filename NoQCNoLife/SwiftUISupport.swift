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
import SFSafeSymbols
import Combine

// MARK: - App State

@available(macOS 11.0, *)
class AppState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectedProduct: Bose.Products?
    @Published var batteryLevel: Int?
    @Published var noiseCancelMode: Bose.AnrMode?
    @Published var bassControlStep: Int?
    
    weak var delegate: AppStateDelegate?
    
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
    
    func setBatteryLevel(_ level: Int?) {
        DispatchQueue.main.async {
            self.batteryLevel = level
        }
    }
    
    func setNoiseCancelMode(_ mode: Bose.AnrMode?) {
        DispatchQueue.main.async {
            self.noiseCancelMode = mode
        }
        
        if let mode = mode {
            delegate?.noiseCancelModeSelected(mode)
        }
    }
    
    func setBassControlStep(_ step: Int?) {
        DispatchQueue.main.async {
            self.bassControlStep = step
        }
        
        if let step = step {
            delegate?.bassControlStepSelected(step)
        }
    }
    
    static var preview: AppState {
        let state = AppState()
        state.isConnected = true
        state.connectedProduct = .BAYWOLF
        state.batteryLevel = 85
        state.noiseCancelMode = .HIGH
        state.bassControlStep = 2
        return state
    }
}

@available(macOS 11.0, *)
protocol AppStateDelegate: AnyObject {
    func noiseCancelModeSelected(_ mode: Bose.AnrMode)
    func bassControlStepSelected(_ step: Int)
}

// MARK: - SwiftUI Delegate

@available(macOS 11.0, *)
class SwiftUIAppDelegate: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var appState = AppState()
    private var bt: Bt!
    private var statusUpdateTimer: Timer?
    
    func setBluetoothInstance(_ bt: Bt) {
        self.bt = bt
        
        // Set up app state delegate
        appState.delegate = self
        
        // Create status bar item
        setupStatusBarItem()
        
        NSLog("[NoQCNoLife]: SwiftUI delegate initialized")
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use SF Symbol with SFSafeSymbols
            let image = NSImage(systemSymbol: .waveformCircle)
            button.image = image
        }
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: 
            SwiftUIContentView()
                .environmentObject(appState)
        )
        
        // Set up status item action
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.target = self
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    private func updateStatusBarIcon(for mode: Bose.AnrMode?) {
        guard let button = statusItem.button else { return }
        
        let symbol: SFSymbol
        
        if mode == nil {
            symbol = .waveformCircle
        } else {
            switch mode! {
            case .HIGH: symbol = .waveformCircleFill
            case .LOW: symbol = .waveformCircle
            case .OFF: symbol = .waveform
            case .WIND: symbol = .waveformPath
            }
        }
        
        let image = NSImage(systemSymbol: symbol)
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        button.image = image.withSymbolConfiguration(symbolConfig) ?? image
        button.needsDisplay = true
    }
}

// MARK: - BluetoothDelegate, DeviceManagementEventHandler

@available(macOS 11.0, *)
extension SwiftUIAppDelegate: BluetoothDelegate, DeviceManagementEventHandler {
    
    func onConnect() {
        NSLog("[NoQCNoLife]: SwiftUI onConnect() called")
        guard let product = Bose.Products.getById(self.bt.getProductId()) else {
            NSLog("[NoQCNoLife]: ERROR - Invalid product id in SwiftUI onConnect()")
            return
        }
        NSLog("[NoQCNoLife]: SwiftUI Connected to \(product.getName())")
        
        appState.connected(to: product)
        
        // Poll for status briefly after connection
        var pollCount = 0
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            pollCount += 1
            _ = self.bt.sendGetAnrModePacket()
            
            if pollCount >= 3 {
                NSLog("[NoQCNoLife]: SwiftUI Stopping initial status polling")
                timer.invalidate()
                self.statusUpdateTimer = nil
            }
        }
        
        // Request battery level and noise cancellation mode after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            NSLog("[NoQCNoLife]: SwiftUI Requesting initial battery level and ANR mode")
            
            if !self.bt.sendGetBatteryLevelPacket() {
                NSLog("[NoQCNoLife]: SwiftUI Failed to send battery level packet")
                self.batteryLevelStatus(nil)
            }
            
            if !self.bt.sendGetAnrModePacket() {
                NSLog("[NoQCNoLife]: SwiftUI Failed to send ANR mode packet")
                self.noiseCancelModeChanged(nil)
            }
        }
    }
    
    func onDisconnect() {
        NSLog("[NoQCNoLife]: SwiftUI Disconnected")
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
        appState.disconnected()
        updateStatusBarIcon(for: nil)
    }
    
    func bassControlStepChanged(_ step: Int?) {
        NSLog("[NoQCNoLife]: SwiftUI Bass control step changed: \(step?.description ?? "nil")")
        appState.setBassControlStep(step)
    }
    
    func batteryLevelStatus(_ level: Int?) {
        NSLog("[NoQCNoLife]: SwiftUI Battery level: \(level?.description ?? "nil")")
        appState.setBatteryLevel(level)
    }
    
    func noiseCancelModeChanged(_ mode: Bose.AnrMode?) {
        NSLog("[NoQCNoLife]: SwiftUI Noise cancel mode changed: \(mode?.toString() ?? "nil")")
        appState.setNoiseCancelMode(mode)
        updateStatusBarIcon(for: mode)
        
        if let mode = mode, let product = Bose.Products.getById(self.bt.getProductId()) {
            PreferenceManager.setLastSelectedAnrMode(product: product, anrMode: mode)
        }
    }
    
    // MARK: - DeviceManagementEventHandler
    
    func onDeviceListReceived(_ devices: [BosePairedDevice]) {
        // Forward to connections window if needed
        NSLog("[NoQCNoLife]: SwiftUI received device list with \(devices.count) devices")
    }
    
    func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        NSLog("[NoQCNoLife]: SwiftUI received device info for \(deviceInfo.macAddress)")
    }
}

// MARK: - AppStateDelegate

@available(macOS 11.0, *)
extension SwiftUIAppDelegate: AppStateDelegate {
    
    func bassControlStepSelected(_ step: Int) {
        if !bt.sendSetGetBassControlPacket(step) {
            bassControlStepChanged(nil)
        }
    }
    
    func noiseCancelModeSelected(_ mode: Bose.AnrMode) {
        if !bt.sendSetGetAnrModePacket(mode) {
            noiseCancelModeChanged(nil)
        }
    }
}

// MARK: - SwiftUI Views

@available(macOS 11.0, *)
struct SwiftUIContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            if appState.isConnected, let product = appState.connectedProduct {
                DeviceStatusView(product: product)
                Divider()
                DeviceControlsView()
            } else {
                DisconnectedView()
            }
            
            Divider()
            ActionButtonsView()
        }
        .frame(width: 250)
    }
}

@available(macOS 11.0, *)
struct DeviceStatusView: View {
    let product: Bose.Products
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(product.getName())
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            if let batteryLevel = appState.batteryLevel {
                HStack {
                    Image(systemName: "battery.100")
                        .foregroundColor(.green)
                    Text("Battery: \(batteryLevel)%")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            if let anrMode = appState.noiseCancelMode {
                HStack {
                    Image(systemName: noiseCancelIcon(for: anrMode))
                        .foregroundColor(noiseCancelColor(for: anrMode))
                    Text("NC: \(anrMode.toString())")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    private var statusIcon: String {
        if let mode = appState.noiseCancelMode {
            switch mode {
            case .HIGH: return "waveform.circle.fill"
            case .LOW: return "waveform.circle"
            case .OFF: return "waveform"
            case .WIND: return "waveform.path"
            }
        }
        return "waveform.circle"
    }
    
    private var statusColor: Color {
        appState.isConnected ? .green : .secondary
    }
    
    private func noiseCancelIcon(for mode: Bose.AnrMode) -> String {
        switch mode {
        case .HIGH: return "speaker.wave.3"
        case .LOW: return "speaker.wave.2"
        case .OFF: return "speaker.slash"
        case .WIND: return "wind"
        }
    }
    
    private func noiseCancelColor(for mode: Bose.AnrMode) -> Color {
        switch mode {
        case .HIGH: return .blue
        case .LOW: return .orange
        case .OFF: return .red
        case .WIND: return .cyan
        }
    }
}

@available(macOS 11.0, *)
struct DisconnectedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "headphones")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No device connected.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

@available(macOS 11.0, *)
struct DeviceControlsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.supportsNoiseCancellation {
                NoiseCancelControlView()
                Divider().padding(.horizontal)
            }
            
            if appState.supportsBassControl {
                BassControlView()
                Divider().padding(.horizontal)
            }
        }
    }
}

@available(macOS 11.0, *)
struct NoiseCancelControlView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Noise Cancellation")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                ForEach(availableModes, id: \.rawValue) { mode in
                    Button(mode.toString()) {
                        appState.setNoiseCancelMode(mode)
                    }
                    .buttonStyle(ControlButtonStyle(isSelected: appState.noiseCancelMode == mode))
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }
    
    private var availableModes: [Bose.AnrMode] {
        guard let product = appState.connectedProduct else { return [] }
        
        switch product {
        case .WOLFCASTLE, .BAYWOLF:
            return [.HIGH, .LOW, .OFF]
        case .KLEOS:
            return []
        }
    }
}

@available(macOS 11.0, *)
struct BassControlView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dialogue Adjust")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            HStack {
                Button("-") {
                    if let current = appState.bassControlStep, current > -8 {
                        appState.setBassControlStep(current - 1)
                    }
                }
                .buttonStyle(ControlButtonStyle(isSelected: false))
                
                Text("\(appState.bassControlStep ?? 0)")
                    .frame(width: 30)
                    .font(.monospaced(.body)())
                
                Button("+") {
                    if let current = appState.bassControlStep, current < 8 {
                        appState.setBassControlStep(current + 1)
                    } else if appState.bassControlStep == nil {
                        appState.setBassControlStep(0)
                    }
                }
                .buttonStyle(ControlButtonStyle(isSelected: false))
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }
}

@available(macOS 11.0, *)
struct ActionButtonsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Button("Connections...") {
                ConnectionsWindowController.shared.showWindow()
            }
            .buttonStyle(ActionButtonStyle())
            
            Button("About") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            .buttonStyle(ActionButtonStyle())
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(ActionButtonStyle())
        }
        .padding()
    }
}

@available(macOS 11.0, *)
struct ControlButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor(configuration: configuration))
            )
            .foregroundColor(foregroundColor(configuration: configuration))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
    
    private func backgroundColor(configuration: Configuration) -> Color {
        if isSelected {
            return configuration.isPressed ? .accentColor.opacity(0.8) : .accentColor
        } else {
            return configuration.isPressed ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.1)
        }
    }
    
    private func foregroundColor(configuration: Configuration) -> Color {
        isSelected ? .white : .primary
    }
}

@available(macOS 11.0, *)
struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.secondary.opacity(0.3) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}