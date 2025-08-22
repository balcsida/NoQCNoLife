import Cocoa
import SwiftUI

@MainActor
final class ConnectionsWindowController: ObservableObject {
    static let shared = ConnectionsWindowController()
    private var window: NSWindow?
    @Published var devices: [BosePairedDevice] = []
    
    nonisolated init() {}
    
    func showWindow() {
        if window == nil {
            let contentView = SimpleConnectionsView()
            
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "Device Connections"
            window?.contentView = NSHostingView(rootView: contentView)
            window?.center()
            window?.isReleasedWhenClosed = false
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Automatically request device list from the headphones when window opens
        refreshDeviceList()
    }
    
    func refreshDeviceList() {
        // Try to get bt through BluetoothManager (defined in NoQCNoLifeApp)
        // If that fails, we skip the refresh
        NSLog("[NoQCNoLife]: ConnectionsWindow - Auto-requesting device list from headphones...")
        
        // For now, just log that we can't refresh without the proper delegate
        NSLog("[NoQCNoLife]: ConnectionsWindow - Device list refresh requested but Bluetooth access is being updated")
        
        // Clear the device list for now
        DispatchQueue.main.async {
            self.devices = []
        }
    }
    
    func didReceiveDeviceList(_ devices: [BosePairedDevice]) {
        DispatchQueue.main.async {
            self.devices = devices
        }
    }
    
    func onDeviceInfoReceived(_ deviceInfo: DeviceInfo) {
        
    }
    
    func onPairingModeResponse(_ isEnabled: Bool) {
        
    }
}

struct SimpleConnectionsView: View {
    @ObservedObject var controller = ConnectionsWindowController.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Device Connections")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            if controller.devices.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No devices found")
                        .font(.headline)
                    Text("No devices are currently connected to your Bose headphones.\nUse 'Refresh' to check for connected devices or 'Enter Pairing Mode' to connect new ones.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(controller.devices, id: \.address) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(device.name ?? "Unknown Device")
                                    .font(.system(.body))
                                
                                Spacer()
                                
                                // Connection status indicator
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(connectionColor(for: device.status))
                                        .frame(width: 8, height: 8)
                                    Text(statusText(for: device.status))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(device.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let deviceInfo = device.deviceInfo {
                                Text(deviceInfo)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            
            HStack {
                Button("Refresh Devices") {
                    ConnectionsWindowController.shared.refreshDeviceList()
                }
                
                Spacer()
                
                Button(action: {
                    NSLog("[NoQCNoLife]: Connections - Pairing mode button clicked")
                    // Pairing mode functionality will be restored once Bluetooth access is updated
                }) {
                    Text("Enter Pairing Mode")
                }
            }
            .padding()
        }
        .frame(width: 600, height: 450)
    }
    
    private func connectionColor(for status: DeviceConnectionStatus) -> Color {
        switch status {
        case .connected:
            return .green
        case .disconnected:
            return .gray
        case .currentDevice:
            return .blue
        }
    }
    
    private func statusText(for status: DeviceConnectionStatus) -> String {
        switch status {
        case .connected:
            return "Connected"
        case .disconnected:
            return "Paired"
        case .currentDevice:
            return "Active"
        }
    }
}