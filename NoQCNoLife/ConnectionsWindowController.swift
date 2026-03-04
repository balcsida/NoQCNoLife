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
        if let bt = BluetoothManager.shared.bt {
            ConnectionsManager.shared.refreshDevices(using: bt)
        }
    }
    
    func refreshDeviceList() {
        guard let bt = BluetoothManager.shared.bt else {
            NSLog("[NoQCNoLife]: ConnectionsWindow - No Bluetooth instance available")
            return
        }

        guard bt.getProductId() != nil else {
            NSLog("[NoQCNoLife]: ConnectionsWindow - No Bose device connected")
            self.devices = []
            return
        }

        NSLog("[NoQCNoLife]: ConnectionsWindow - Requesting device list from headphones")
        _ = bt.sendListDevicesPacket()
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
    @ObservedObject var manager = ConnectionsManager.shared
    @State private var selectedAddress: String?
    @State private var showingRemoveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            if manager.devices.isEmpty {
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
                List(manager.devices, id: \.address, selection: $selectedAddress) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name ?? "Unknown Device")
                                .font(.system(.body))

                            Text(device.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Circle()
                                .fill(connectionColor(for: device.status))
                                .frame(width: 8, height: 8)
                            Text(statusText(for: device.status))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Button("Refresh") {
                    if let bt = BluetoothManager.shared.bt {
                        manager.refreshDevices(using: bt)
                    }
                }

                Button("Connect") {
                    performAction { bt, device in
                        manager.connectToDevice(device, using: bt) { _ in }
                    }
                }
                .disabled(!canConnect)

                Button("Disconnect") {
                    performAction { bt, device in
                        manager.disconnectFromDevice(device, using: bt) { _ in }
                    }
                }
                .disabled(!canDisconnect)

                Button("Remove") {
                    showingRemoveConfirmation = true
                }
                .disabled(!canRemove)

                Spacer()

                Button(action: {
                    guard let bt = BluetoothManager.shared.bt else { return }
                    if manager.isPairingModeActive {
                        _ = bt.sendExitPairingModePacket()
                    } else {
                        _ = bt.sendEnterPairingModePacket()
                    }
                }) {
                    Text(manager.isPairingModeActive
                         ? "Exit Pairing Mode" : "Enter Pairing Mode")
                }
            }
            .padding()
        }
        .frame(width: 600, height: 450)
        .confirmationDialog("Remove Device Pairing", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                performAction { bt, device in
                    manager.removeDevicePairing(device, using: bt) { _ in }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove this device from the Bose headphone's paired device list?")
        }
    }

    private var selectedDevice: BosePairedDevice? {
        guard let addr = selectedAddress else { return nil }
        return manager.devices.first { $0.address == addr }
    }

    private var canConnect: Bool {
        selectedDevice?.status == .disconnected
    }

    private var canDisconnect: Bool {
        selectedDevice?.status == .connected
    }

    private var canRemove: Bool {
        guard let device = selectedDevice else { return false }
        return device.status != .currentDevice
    }

    private func performAction(_ action: (Bt, BosePairedDevice) -> Void) {
        guard let bt = BluetoothManager.shared.bt, let device = selectedDevice else { return }
        action(bt, device)
    }

    private func connectionColor(for status: DeviceConnectionStatus) -> Color {
        switch status {
        case .connected: return .green
        case .disconnected: return .gray
        case .currentDevice: return .blue
        }
    }

    private func statusText(for status: DeviceConnectionStatus) -> String {
        switch status {
        case .connected: return "Connected"
        case .disconnected: return "Paired"
        case .currentDevice: return "Active"
        }
    }
}