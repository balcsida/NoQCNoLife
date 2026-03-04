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
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderSection()

            Divider()

            if appState.isConnected {
                ConnectedContentView()
            } else {
                DisconnectedView()
            }

            Divider()

            // Footer actions
            FooterSection()
        }
        .frame(width: 280)
    }
}

// MARK: - Header

private struct HeaderSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            Image(systemName: "headphones")
                .font(.title2)
                .foregroundColor(appState.isConnected ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.connectedProduct?.getName() ?? "No QC, No Life")
                    .font(.headline)

                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(appState.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let level = appState.batteryLevel {
                BatteryIndicator(level: level)
            }
        }
        .padding()
    }
}

// MARK: - Battery Indicator

private struct BatteryIndicator: View {
    let level: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIconName)
                .foregroundColor(batteryColor)
            Text("\(level)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var batteryIconName: String {
        switch level {
        case 0..<10: return "battery.0percent"
        case 10..<35: return "battery.25percent"
        case 35..<65: return "battery.50percent"
        case 65..<90: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var batteryColor: Color {
        if level < 15 { return .red }
        if level < 30 { return .orange }
        return .green
    }
}

// MARK: - Connected Content

private struct ConnectedContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if appState.supportsNoiseCancellation {
                    NoiseCancellationSection()
                }

                if appState.supportsBassControl {
                    BassControlSection()
                }

                if !appState.supportsNoiseCancellation && !appState.supportsBassControl {
                    Text("No adjustable settings for this device.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Noise Cancellation

private struct NoiseCancellationSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Noise Cancellation", systemImage: "ear")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(appState.supportedAnrModes, id: \.rawValue) { mode in
                    Button(action: {
                        appDelegate.userSelectedNoiseCancelMode(mode)
                    }) {
                        Text(mode.toString())
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(appState.noiseCancelMode == mode
                                          ? Color.accentColor.opacity(0.2)
                                          : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(appState.noiseCancelMode == mode
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.3),
                                            lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Bass Control

private struct BassControlSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appDelegate: AppDelegate

    // Bass control range: -2 to +2 (5 steps)
    private let minStep = -2
    private let maxStep = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Bass Level", systemImage: "speaker.wave.3")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Text("−")
                    .font(.body.weight(.bold))
                    .foregroundColor(.secondary)

                Slider(
                    value: bassBinding,
                    in: Double(minStep)...Double(maxStep),
                    step: 1
                )

                Text("+")
                    .font(.body.weight(.bold))
                    .foregroundColor(.secondary)
            }

            if let step = appState.bassControlStep {
                Text("Level: \(step > 0 ? "+" : "")\(step)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal)
    }

    private var bassBinding: Binding<Double> {
        Binding(
            get: { Double(appState.bassControlStep ?? 0) },
            set: { newValue in
                let step = Int(newValue)
                appDelegate.userSelectedBassControlStep(step)
            }
        )
    }
}

// MARK: - Disconnected View

private struct DisconnectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "headphones")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Bose device connected")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Connect your Bose headphones via Bluetooth to get started.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Footer

private struct FooterSection: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        HStack {
            Button(action: { appDelegate.showConnectionsWindow() }) {
                Label("Connections", systemImage: "link")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { appDelegate.showDebugWindow() }) {
                Label("Debug", systemImage: "ladybug")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
