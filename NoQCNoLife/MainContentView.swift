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

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appDelegate: SwiftUIAppDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            if appState.isConnected, let product = appState.connectedProduct {
                DeviceStatusView(product: product)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                DeviceControlsView()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
            } else {
                DisconnectedView()
                    .padding(.vertical, 20)
            }
            
            Divider()
            
            ActionButtonsView()
                .padding(16)
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct DeviceStatusView: View {
    let product: Bose.Products
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Device name and connection status
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 16))
                Text(product.getName())
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            
            // Battery level
            if let batteryLevel = appState.batteryLevel {
                HStack(spacing: 8) {
                    Image(systemName: batteryIcon(for: batteryLevel))
                        .foregroundColor(batteryColor(for: batteryLevel))
                        .font(.system(size: 13))
                    Text("Battery: \(batteryLevel)%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // Noise cancellation status
            if let anrMode = appState.noiseCancelMode {
                HStack(spacing: 8) {
                    Image(systemName: noiseCancelIcon(for: anrMode))
                        .foregroundColor(noiseCancelColor(for: anrMode))
                        .font(.system(size: 13))
                    Text("Noise Cancellation: \(anrMode.toString())")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // Bass control status
            if appState.supportsBassControl, let bassLevel = appState.bassControlStep {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.blue)
                        .font(.system(size: 13))
                    Text("Dialogue Adjust: \(bassLevel)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
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
    
    private func batteryIcon(for level: Int) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        if level > 10 { return "battery.25" }
        return "battery.0"
    }
    
    private func batteryColor(for level: Int) -> Color {
        if level > 50 { return .green }
        if level > 20 { return .orange }
        return .red
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
        case .OFF: return .gray
        case .WIND: return .cyan
        }
    }
}

struct DisconnectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "headphones")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No device connected")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DeviceControlsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appDelegate: SwiftUIAppDelegate
    
    var body: some View {
        VStack(spacing: 16) {
            if appState.supportsNoiseCancellation {
                NoiseCancelControlView()
            }
            
            if appState.supportsBassControl {
                BassControlView()
            }
        }
    }
}

struct NoiseCancelControlView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appDelegate: SwiftUIAppDelegate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Noise Cancellation")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(availableModes, id: \.rawValue) { mode in
                    Button(action: {
                        appDelegate.userSelectedNoiseCancelMode(mode)
                    }) {
                        Text(mode.toString())
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ControlButtonStyle(isSelected: appState.noiseCancelMode == mode))
                }
            }
        }
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

struct BassControlView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appDelegate: SwiftUIAppDelegate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dialogue Adjust")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button(action: {
                    if let current = appState.bassControlStep, current > -8 {
                        appDelegate.userSelectedBassControlStep(current - 1)
                    } else if appState.bassControlStep == nil {
                        appDelegate.userSelectedBassControlStep(-1)
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(ControlButtonStyle(isSelected: false))
                
                Text("\(appState.bassControlStep ?? 0)")
                    .frame(width: 40)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary)
                
                Button(action: {
                    if let current = appState.bassControlStep, current < 8 {
                        appDelegate.userSelectedBassControlStep(current + 1)
                    } else if appState.bassControlStep == nil {
                        appDelegate.userSelectedBassControlStep(1)
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(ControlButtonStyle(isSelected: false))
            }
        }
    }
}

struct ActionButtonsView: View {
    var body: some View {
        VStack(spacing: 6) {
            Button(action: {
                ConnectionsWindowController.shared.showWindow()
            }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12))
                    Text("Connections...")
                        .font(.system(size: 13))
                    Spacer()
                }
            }
            .buttonStyle(MenuButtonStyle())
            
            Button(action: {
                DebugWindowController.shared.showWindow()
            }) {
                HStack {
                    Image(systemName: "ladybug")
                        .font(.system(size: 12))
                    Text("Debug Log...")
                        .font(.system(size: 13))
                    Spacer()
                }
            }
            .buttonStyle(MenuButtonStyle())
            
            Divider()
                .padding(.vertical, 4)
            
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }) {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("About")
                        .font(.system(size: 13))
                    Spacer()
                }
            }
            .buttonStyle(MenuButtonStyle())
            
            Button(action: {
                NSApp.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                    Text("Quit")
                        .font(.system(size: 13))
                    Spacer()
                }
            }
            .buttonStyle(MenuButtonStyle())
        }
    }
}

struct ControlButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(configuration: configuration))
            )
            .foregroundColor(foregroundColor(configuration: configuration))
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(configuration: Configuration) -> Color {
        if isSelected {
            return configuration.isPressed ? Color.accentColor.opacity(0.9) : Color.accentColor
        } else {
            return configuration.isPressed ? 
                Color(NSColor.controlBackgroundColor).opacity(0.8) : 
                Color(NSColor.controlBackgroundColor)
        }
    }
    
    private func foregroundColor(configuration: Configuration) -> Color {
        isSelected ? .white : Color(NSColor.labelColor)
    }
}

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? 
                        Color.accentColor.opacity(0.2) : 
                        Color.clear)
            )
            .contentShape(Rectangle())
            .foregroundColor(configuration.isPressed ? .accentColor : .primary)
    }
}

#Preview {
    MainContentView()
        .environmentObject(AppState())
        .environmentObject(SwiftUIAppDelegate())
}