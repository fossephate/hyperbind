import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.left", accessibilityDescription: "HyperJ")
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "HyperJ → ←", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Set up event tap to monitor key presses
        setupEventTap()
    }
    
    func setupEventTap() {
        // CGEventMask to listen for keyDown and keyUp events
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

// Hyper key is typically Control+Option+Command+Shift
func isHyperKeyPressed(flags: CGEventFlags) -> Bool {
    let hyperKeyFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
    return flags.contains(hyperKeyFlags)
}

// Event callback function
func eventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // Extract keycode from the event
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    
    // Check if it's a 'j' key press (keycode 38) with Hyper key modifier
    if keyCode == 38 /* j key */ {
        // Get event flags to check modifiers
        let flags = event.flags
        
        if isHyperKeyPressed(flags: flags) {
            // Create a left arrow key event instead
            let leftArrowKeyCode: CGKeyCode = 123 // Left arrow key
            
            if type == .keyDown {
                let leftArrowEvent = CGEvent(keyboardEventSource: CGEventSource(stateID: .combinedSessionState), 
                                           virtualKey: leftArrowKeyCode, 
                                           keyDown: true)
                
                // Ensure we strip all modifiers from the new event
                leftArrowEvent?.flags = CGEventFlags()

                leftArrowEvent?.setIntegerValueField(.eventSourceUserData, value: Int64(arc4random()))
                
                // Post the event to the system
                leftArrowEvent?.post(tap: .cgAnnotatedSessionEventTap)
                
                NSLog("Fired down")
            } else if type == .keyUp {
                let leftArrowEvent = CGEvent(keyboardEventSource: CGEventSource(stateID: .combinedSessionState), 
                                           virtualKey: leftArrowKeyCode, 
                                           keyDown: false)
                
                // Ensure we strip all modifiers from the new event
                leftArrowEvent?.flags = CGEventFlags()

                leftArrowEvent?.setIntegerValueField(.eventSourceUserData, value: Int64(arc4random()))
                
                // Post the event to the system
                leftArrowEvent?.post(tap: .cgAnnotatedSessionEventTap)
                
                NSLog("Fired up")
            }
            
            // Consume the original event
            return nil
        }
    }
    
    // Pass through all other events
    return Unmanaged.passRetained(event)
}

// Main application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()