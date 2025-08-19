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

class DebugWindowController: NSWindowController {
    
    static let shared = DebugWindowController()
    
    private var logTextView: NSTextView!
    private var commandTextField: NSTextField!
    private var sendButton: NSButton!
    private var clearButton: NSButton!
    private var scrollView: NSScrollView!
    
    private var logMessages: [String] = []
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.title = "BMAP Debug Console"
        window.center()
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        let contentView = NSView(frame: window.contentView!.frame)
        window.contentView = contentView
        
        // Log display area
        scrollView = NSScrollView(frame: NSRect(x: 20, y: 100, width: 760, height: 450))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder
        
        logTextView = NSTextView()
        logTextView.isEditable = false
        logTextView.isSelectable = true
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.backgroundColor = NSColor.controlBackgroundColor
        logTextView.textColor = NSColor.labelColor
        logTextView.string = "BMAP Debug Console - Ready\n"
        
        scrollView.documentView = logTextView
        contentView.addSubview(scrollView)
        
        // Command input area
        let commandLabel = NSTextField(frame: NSRect(x: 20, y: 60, width: 100, height: 20))
        commandLabel.stringValue = "BMAP Command:"
        commandLabel.isEditable = false
        commandLabel.isBordered = false
        commandLabel.backgroundColor = NSColor.clear
        contentView.addSubview(commandLabel)
        
        commandTextField = NSTextField(frame: NSRect(x: 130, y: 60, width: 500, height: 25))
        commandTextField.placeholderString = "Enter hex bytes (e.g., 04 04 01 00)"
        commandTextField.target = self
        commandTextField.action = #selector(sendCommand)
        contentView.addSubview(commandTextField)
        
        sendButton = NSButton(frame: NSRect(x: 640, y: 58, width: 60, height: 28))
        sendButton.title = "Send"
        sendButton.bezelStyle = .rounded
        sendButton.action = #selector(sendCommand)
        sendButton.target = self
        contentView.addSubview(sendButton)
        
        clearButton = NSButton(frame: NSRect(x: 710, y: 58, width: 60, height: 28))
        clearButton.title = "Clear"
        clearButton.bezelStyle = .rounded
        clearButton.action = #selector(clearLogs)
        clearButton.target = self
        contentView.addSubview(clearButton)
        
        // Preset command buttons
        let presetY = 20
        addPresetButton("LIST_DEVICES", command: "04 04 01 00", x: 20, y: presetY)
        addPresetButton("BATTERY", command: "02 02 01 00", x: 120, y: presetY)
        addPresetButton("ANR MODE", command: "01 06 01 00", x: 200, y: presetY)
        addPresetButton("PAIRING_MODE", command: "04 08 05 01 01", x: 290, y: presetY)
        
        let infoLabel = NSTextField(frame: NSRect(x: 400, y: presetY, width: 380, height: 20))
        infoLabel.stringValue = "Press Option+Click on menu bar to open debug console"
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.backgroundColor = NSColor.clear
        infoLabel.textColor = NSColor.secondaryLabelColor
        infoLabel.font = NSFont.systemFont(ofSize: 10)
        contentView.addSubview(infoLabel)
        
        updateButtonStates()
    }
    
    private func addPresetButton(_ title: String, command: String, x: Int, y: Int) {
        let button = NSButton(frame: NSRect(x: x, y: y, width: 80, height: 25))
        button.title = title
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 10)
        button.target = self
        button.action = #selector(presetButtonClicked(_:))
        button.tag = command.hashValue
        button.toolTip = "Send: \(command)"
        window?.contentView?.addSubview(button)
        
        // Store the command in the button's identifier
        button.identifier = NSUserInterfaceItemIdentifier(command)
    }
    
    @objc private func presetButtonClicked(_ sender: NSButton) {
        if let command = sender.identifier?.rawValue {
            commandTextField.stringValue = command
            sendCommand()
        }
    }
    
    @objc private func sendCommand() {
        let commandText = commandTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandText.isEmpty else { return }
        
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            addLog("ERROR: Cannot access AppDelegate")
            return
        }
        
        guard appDelegate.bt.getProductId() != nil else {
            addLog("ERROR: No Bose device connected")
            return
        }
        
        // Parse hex command
        let hexComponents = commandText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .joined()
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        
        var packet: [Int8] = []
        for hexString in hexComponents {
            guard let byte = UInt8(hexString, radix: 16) else {
                addLog("ERROR: Invalid hex byte: \(hexString)")
                return
            }
            packet.append(Int8(bitPattern: byte))
        }
        
        guard packet.count >= 4 else {
            addLog("ERROR: Packet too short (minimum 4 bytes required)")
            return
        }
        
        addLog("SENDING: \(commandText) -> \(packet)")
        
        // Send the packet directly through the BT layer
        if appDelegate.bt.sendRawPacket(packet) {
            addLog("SUCCESS: Packet sent")
            commandTextField.stringValue = ""
        } else {
            addLog("ERROR: Failed to send packet")
        }
    }
    
    @objc private func clearLogs() {
        logMessages.removeAll()
        logTextView.string = "BMAP Debug Console - Cleared\n"
    }
    
    func showWindow() {
        updateButtonStates()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func updateButtonStates() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            sendButton.isEnabled = false
            return
        }
        
        sendButton.isEnabled = (appDelegate.bt.getProductId() != nil)
        
        // Update preset buttons
        let isConnected = (appDelegate.bt.getProductId() != nil)
        window?.contentView?.subviews.compactMap { $0 as? NSButton }.forEach { button in
            if button != sendButton && button != clearButton && button.identifier != nil {
                button.isEnabled = isConnected
            }
        }
    }
    
    func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)\n"
        
        DispatchQueue.main.async {
            self.logMessages.append(logEntry)
            
            // Keep only last 1000 log entries
            if self.logMessages.count > 1000 {
                self.logMessages.removeFirst(100)
            }
            
            self.logTextView.string = self.logMessages.joined()
            
            // Auto-scroll to bottom
            self.logTextView.scrollToEndOfDocument(nil)
        }
    }
}