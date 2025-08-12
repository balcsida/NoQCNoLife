/*
 Copyright (C) 2021 Shun Ito
 
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
import SFSafeSymbols

class StatusItem {
    
    var statusItem: NSStatusItem
    var statusItemDelegate: StatusItemDelegate
    
    enum MenuItemTags: Int {
        case UNDEFINED, // NSMenuItemのtagに0を指定すると、なぜかNSMenu.item(withTag: tag)でエラーが出る。
        ABOUT,
        BASS_CONTROL,
        BATTERY_LEVEL,
        DEVICE_NAME,
        NOISE_CANCEL_MODE,
        QUIT
    }
    
    init (_ delegate: StatusItemDelegate) {
        
        self.statusItemDelegate = delegate
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Use SF Symbol for menu bar icon with SFSafeSymbols
        let image = NSImage(systemSymbol: .waveformCircle)
        self.statusItem.button?.image = image

        let mainMenu = NSMenu.init()
        mainMenu.delegate = delegate
//        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(DeviceNameMenuItem.init())
        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(AboutMenuItem.init())
        mainMenu.addItem(QuitMenuItem.init())

        self.statusItem.menu = mainMenu
    }
    
    func buildMenuItems(_ product: Bose.Products) -> [NSMenuItem] {
        var menuItems: [NSMenuItem] = []
        switch product {
        case Bose.Products.WOLFCASTLE: // QuietComfort 35
            menuItems.append(BatteryLevelMenuItem.init())
            menuItems.append(NoiseCancelModeMenuItem.init(high: true, low: true, wind: false, off: true,
                                                          delegate: self.statusItemDelegate))
        case Bose.Products.BAYWOLF: // Bose QuietComfort 35 Series 2
            menuItems.append(BatteryLevelMenuItem.init())
            menuItems.append(NoiseCancelModeMenuItem.init(high: true, low: true, wind: false, off: true,
                                                          delegate: self.statusItemDelegate))
        case Bose.Products.KLEOS: // SoundWear
            menuItems.append(BatteryLevelMenuItem.init())
            menuItems.append(BassControlMenuItem.init(steps:8, delegate: self.statusItemDelegate))
        }
        return menuItems
    }
    
    func isConnected() -> Bool {
        let deviceNameMenuItemTag = StatusItem.MenuItemTags.DEVICE_NAME.rawValue
        let deviceNameMenuItem = self.statusItem.menu?.item(withTag: deviceNameMenuItemTag) as? DeviceNameMenuItem
        return deviceNameMenuItem?.hasDeviceName() ?? false
    }
    
    func connected (_ product: Bose.Products!) {
        let deviceNameMenuItemTag = StatusItem.MenuItemTags.DEVICE_NAME.rawValue
        let deviceNameMenuItem = self.statusItem.menu?.item(withTag: deviceNameMenuItemTag) as! DeviceNameMenuItem
        
        // Check if already connected to prevent duplicate menu items
        if deviceNameMenuItem.hasDeviceName() {
            #if DEBUG
            print("[StatusItem]: Already connected, skipping duplicate menu items")
            #endif
            return
        }
        
        deviceNameMenuItem.setDeviceName(product.getName())
        
        for menuItem in buildMenuItems(product).reversed() {
            self.statusItem.menu?.insertItem(menuItem, at: 1)
        }
    }
    
    func disconnected () {
        let deviceNameMenuItemTag = StatusItem.MenuItemTags.DEVICE_NAME.rawValue
        let deviceNameMenuItem = self.statusItem.menu?.item(withTag: deviceNameMenuItemTag) as! DeviceNameMenuItem
        deviceNameMenuItem.clearDeviceName()
        
        for menuItem in self.statusItem.menu?.items ?? [] {
            if (menuItem.tag != MenuItemTags.ABOUT.rawValue &&
                menuItem.tag != MenuItemTags.DEVICE_NAME.rawValue &&
                menuItem.tag != MenuItemTags.QUIT.rawValue &&
                !menuItem.isSeparatorItem) {
                menuItem.menu?.removeItem(menuItem)
            }
        }
        
        // Reset icon to default when disconnected
        updateButtonImage(for: nil)
    }
    
    func setBassControlStep(_ step: Int?) {
        let tag = StatusItem.MenuItemTags.BASS_CONTROL.rawValue
        guard let menuItem = self.statusItem.menu?.item(withTag: tag) as? BassControlMenuItem else {
            #if DEBUG
            print("[StatusItem]: Bass control menu item not found, skipping update")
            #endif
            return
        }
        menuItem.setBassControlStep(step)
    }
    
    func setBatteryLevel(_ level: Int?) {
        let tag = StatusItem.MenuItemTags.BATTERY_LEVEL.rawValue
        guard let menuItem = self.statusItem.menu?.item(withTag: tag) as? BatteryLevelMenuItem else {
            #if DEBUG
            print("[StatusItem]: Battery menu item not found, skipping update")
            #endif
            return
        }
        menuItem.setBatteryLevel(level)
    }
    
    func setNoiseCancelMode(_ mode: Bose.AnrMode?) {
        let tag: Int = StatusItem.MenuItemTags.NOISE_CANCEL_MODE.rawValue
        guard let menuItem = self.statusItem.menu?.item(withTag: tag) as? NoiseCancelModeMenuItem else {
            #if DEBUG
            print("[StatusItem]: Noise cancellation menu item not found, skipping update")
            #endif
            return
        }
        menuItem.setNoiseCancelMode(mode)
        
        // Update menu bar icon based on noise cancellation mode
        updateButtonImage(for: mode)
    }
    
    private func updateButtonImage(for mode: Bose.AnrMode?) {
        // Use SF Symbols with SFSafeSymbols
        let symbol: SFSymbol
        
        if mode == nil {
            // No device connected - use basic waveform circle
            symbol = .waveformCircle
        } else {
            switch mode! {
            case .HIGH:
                // High noise cancellation - filled circle with waveform
                symbol = .waveformCircleFill
            case .LOW:
                // Low noise cancellation - regular circle with waveform
                symbol = .waveformCircle
            case .OFF:
                // Noise cancellation off - just waveform
                symbol = .waveform
            case .WIND:
                // Wind mode - use waveform with path
                symbol = .waveformPath
            }
        }
        
        #if DEBUG
        print("[StatusItem]: Updating button image for mode: \(mode?.toString() ?? "nil") with symbol: \(symbol)")
        #endif
        
        let image = NSImage(systemSymbol: symbol)
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        self.statusItem.button?.image = image.withSymbolConfiguration(symbolConfig) ?? image
        
        // Force the status item to redraw
        self.statusItem.button?.needsDisplay = true
    }
}


protocol StatusItemDelegate : NSMenuDelegate {
    func bassControlStepSelected(_ step: Int)
    func noiseCancelModeSelected(_ mode: Bose.AnrMode)
}


class AboutMenuItem : NSMenuItem {
    init() {
        super.init(title: "About No QC, No Life", action: #selector(self.openAboutPanel(_:)), keyEquivalent: "")
        self.tag = StatusItem.MenuItemTags.ABOUT.rawValue
        self.target = self
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func openAboutPanel(_ sender: NSMenuItem) {
        // MenuItemのactionから直接orderFrontStandardAboutPanel()を呼ぶと、
        // バックグラウンドになってしまい、パネルが表示されないので、
        // 一旦フォアグランドにしてから、パネルを表示する。
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

class BassControlMenuItem : NSMenuItem {
    
    var delegate: StatusItemDelegate
    var steps: Int
    var titleStr = "Dialogue Adjust"
    
    init(steps: Int, delegate: StatusItemDelegate) {
        self.steps = steps
        self.delegate = delegate
        
        super.init(title: "\(titleStr): N/A", action: nil, keyEquivalent: "")
        
        self.tag = StatusItem.MenuItemTags.BASS_CONTROL.rawValue
        self.target = self
        self.submenu = buildSubmenu()
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    @objc func bassControlStepSelected(_ sender: NSMenuItem) {
        self.delegate.bassControlStepSelected(sender.tag)
    }
    
    func buildSubmenu() -> NSMenu {
        let submenu = NSMenu.init()
        
        for step in 0 ... self.steps {
            let menuItem = NSMenuItem.init(title: String(step - step * 2),
                                           action: #selector(self.bassControlStepSelected(_:)),
                                           keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = step - step * 2
            submenu.addItem(menuItem)
        }
        
        return submenu
    }
    
    func setBassControlStep(_ step: Int?) {
        if (step == nil) {
            self.title = "\(titleStr): error"
        } else {
            self.title = "\(titleStr): \(step!)"
        }
    }
}


class BatteryLevelMenuItem : NSMenuItem {
    
    init() {
        super.init(title: "Battery: N/A", action: nil, keyEquivalent: "")
        self.tag = StatusItem.MenuItemTags.BATTERY_LEVEL.rawValue
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setBatteryLevel(_ level: Int?) {
        if (level == nil) {
            self.title = "Battery: error"
        } else {
            self.title = "Battery: \(level!)%"
        }
    }
}


class DeviceNameMenuItem : NSMenuItem {
    
    private let defaultTitle = "No device connected."
    
    init() {
        super.init(title: self.defaultTitle, action: nil, keyEquivalent: "")
        self.tag = StatusItem.MenuItemTags.DEVICE_NAME.rawValue
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func clearDeviceName() {
        self.title = defaultTitle
    }
    
    func setDeviceName(_ name: String) {
        self.title = name
    }
    
    func hasDeviceName() -> Bool {
        return self.title != defaultTitle
    }
}


class NoiseCancelModeMenuItem : NSMenuItem {
    
    var delegate: StatusItemDelegate
    
    init(high: Bool, low: Bool, wind: Bool, off: Bool, delegate: StatusItemDelegate) {
        
        self.delegate = delegate
        
        super.init(title: "Noise cancellation: N/A", action: nil, keyEquivalent: "")
        
        self.tag = StatusItem.MenuItemTags.NOISE_CANCEL_MODE.rawValue
        self.target = self
        self.submenu = buildSubmenu(high: high, low: low, wind: wind, off: off)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildSubmenu(high: Bool, low: Bool, wind: Bool, off: Bool) -> NSMenu {
        let submenu = NSMenu.init()
        for mode in Bose.AnrMode.allCases {
            if (mode == Bose.AnrMode.HIGH && !high) {
                continue
            } else if (mode == Bose.AnrMode.LOW && !low) {
                continue
            } else if (mode == Bose.AnrMode.WIND && !wind) {
                continue
            } else if (mode == Bose.AnrMode.OFF && !off) {
                continue
            }
            
            let menuItem = NSMenuItem.init(title: mode.toString(),
                                           action: #selector(self.noiseCancelModeSelected(_:)),
                                           keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = Int(mode.rawValue)
            submenu.addItem(menuItem)
        }
        
        // OFFは順番的にLOWの次にしたい、それだけ。
        let offMenuItem = submenu.item(withTag: Int(Bose.AnrMode.OFF.rawValue))
        submenu.removeItem(offMenuItem!)
        submenu.insertItem(offMenuItem!, at: submenu.numberOfItems)
        
        return submenu
    }
    
    @objc func noiseCancelModeSelected(_ sender: NSMenuItem) {
        switch sender.tag {
        case Int(Bose.AnrMode.OFF.rawValue):
            self.delegate.noiseCancelModeSelected(Bose.AnrMode.OFF)
        case Int(Bose.AnrMode.HIGH.rawValue):
            self.delegate.noiseCancelModeSelected(Bose.AnrMode.HIGH)
        case Int(Bose.AnrMode.WIND.rawValue):
            self.delegate.noiseCancelModeSelected(Bose.AnrMode.WIND)
        case Int(Bose.AnrMode.LOW.rawValue):
            self.delegate.noiseCancelModeSelected(Bose.AnrMode.LOW)
        default:
            assert(false, "Invalid menu item")
        }
    }
    
    func setNoiseCancelMode(_ mode: Bose.AnrMode!) {
        if (mode == nil) {
            self.title = "Noise cancellation: error"
            for subMenuItem in self.submenu?.items ?? [] {
                subMenuItem.state = NSControl.StateValue.off
            }
        } else {
            self.title = "Noise cancellation: \(mode.toString())"
            for subMenuItem in self.submenu?.items ?? [] {
                if (subMenuItem.tag == mode.rawValue) {
                    subMenuItem.state = NSControl.StateValue.on
                } else {
                    subMenuItem.state = NSControl.StateValue.off
                }
            }
        }
    }
}

class QuitMenuItem : NSMenuItem {
    init() {
        super.init(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        self.tag = StatusItem.MenuItemTags.QUIT.rawValue
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
