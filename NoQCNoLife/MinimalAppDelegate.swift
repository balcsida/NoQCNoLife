import Cocoa

@main
class MinimalAppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet var statusMenu: NSMenu!
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // This should write immediately when the app launches
        let logPath = "/tmp/noqc_minimal.txt"
        try? "App launched at \(Date())\n".write(toFile: logPath, atomically: true, encoding: .utf8)
        print("MinimalAppDelegate: applicationDidFinishLaunching called")
        
        // Set as menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Create status item
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        // Set a simple title
        if let button = statusItem?.button {
            button.title = "QC"
            try? "Button created\n".appendingFormat(to: logPath)
        }
        
        // Create a simple menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        try? "Menu created\n".appendingFormat(to: logPath)
        print("MinimalAppDelegate: Setup complete")
    }
}

extension String {
    func appendingFormat(to path: String) throws {
        if let data = self.data(using: .utf8),
           let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        }
    }
}