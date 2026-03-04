import Cocoa
import SwiftUI

@MainActor
final class DebugWindowController {
    static let shared = DebugWindowController()
    private var window: NSWindow?
    
    nonisolated init() {}
    
    func showWindow() {
        if window == nil {
            let contentView = DebugView()
            
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "Debug Log"
            window?.contentView = NSHostingView(rootView: contentView)
            window?.center()
            window?.isReleasedWhenClosed = false
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func addLog(_ message: String) {
        DebugLogger.shared.addLog(message)
    }
}

struct DebugView: View {
    @StateObject private var logger = DebugLogger.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logger.logs.indices, id: \.self) { index in
                            HStack(alignment: .top) {
                                Text(logger.logs[index].timestamp)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text(logger.logs[index].message)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .id(index)
                        }
                    }
                }
                .onChange(of: logger.logs.count) { _ in
                    if !logger.logs.isEmpty {
                        proxy.scrollTo(logger.logs.count - 1, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Clear") {
                    logger.clearLogs()
                }
            }
            .padding(8)
        }
        .frame(width: 800, height: 600)
    }
}

@MainActor
final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    @Published var logs: [LogEntry] = []
    private let maxLogs = 1000
    
    nonisolated init() {}
    
    func addLog(_ message: String) {
        let entry = LogEntry(
            timestamp: DateFormatter.timeFormatter.string(from: Date()),
            message: message
        )
        
        logs.append(entry)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }
    
    func clearLogs() {
        logs.removeAll()
    }
}

struct LogEntry {
    let timestamp: String
    let message: String
}

private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}