import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var capsLockPressed = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "capslock", accessibilityDescription: "CapsHyper")
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "CapsHyper (Caps Lock → Hyper Key)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Set up event tap to monitor key presses
        setupEventTap()
    }
    
    func setupEventTap() {
        // CGEventMask to listen for keyDown, keyUp, and flagsChanged events
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        // Create event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            NSLog("Failed to create event tap")
            NSApp.terminate(nil)
            return
        }
        
        // Save the event tap
        eventTap = tap
        
        // Create a run loop source and add it to the current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: tap, enable: true)
        
        NSLog("Event tap set up successfully")
    }
    
    @objc func quit() {
        NSApp.terminate(nil)
    }
    
    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }
}

// Define the Caps Lock key code
let kVK_CapsLock: CGKeyCode = 0x39

// Get AppDelegate from the refcon
func getAppDelegate(from refcon: UnsafeMutableRawPointer?) -> AppDelegate? {
    guard let refcon = refcon else { return nil }
    return Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
}

// Create the hyper key flags (Command + Control + Option + Shift)
let hyperKeyFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

// Event callback function
func eventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let appDelegate = getAppDelegate(from: refcon)
    
    // Handle flags changed events (modifier key press/release)
    if type == .flagsChanged {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Check if it's the Caps Lock key
        if keyCode == kVK_CapsLock {
            // Determine if Caps Lock is being pressed or released
            // Caps Lock is special because the flags don't work like other modifiers
            // We need to toggle our state variable
            appDelegate?.capsLockPressed.toggle()
            
            NSLog("Caps Lock \(appDelegate?.capsLockPressed == true ? "pressed" : "released")")
            
            if appDelegate?.capsLockPressed == true {
                // When Caps Lock is pressed, we simulate pressing all Hyper key modifiers
                // We don't generate a new event here, but modify all subsequent events
                NSLog("Hyper key activated")
            } else {
                // When Caps Lock is released, we simulate releasing all Hyper key modifiers
                NSLog("Hyper key deactivated")
            }
            
            // Suppress the original Caps Lock event
            return nil
        }
    }
    
    // For all other key events, if Caps Lock is being held down,
    // add the Hyper key modifiers to the event
    if appDelegate?.capsLockPressed == true {
        // Skip modifier key events themselves
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isModifierKey = (keyCode == 54 || // Right Command
                           keyCode == 55 || // Left Command
                           keyCode == 56 || // Left Shift
                           keyCode == 57 || // Caps Lock
                           keyCode == 58 || // Option
                           keyCode == 59 || // Control
                           keyCode == 60 || // Right Shift
                           keyCode == 61 || // Right Option
                           keyCode == 62)   // Right Control
        
        if !isModifierKey {
            // Add Hyper modifiers to the event
            event.flags.insert(hyperKeyFlags)
            NSLog("Added Hyper modifiers to key event: \(keyCode)")
        }
    }
    
    // Pass through the event (possibly modified)
    return Unmanaged.passRetained(event)
}

// Main application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()