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
struct ContentView: View {
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
                if #available(macOS 11.0, *) {
                    SwiftUIConnectionsWindowController.shared.showWindow()
                }
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

@available(macOS 11.0, *)
#Preview {
    ContentView()
        .environmentObject(AppState.preview)
}