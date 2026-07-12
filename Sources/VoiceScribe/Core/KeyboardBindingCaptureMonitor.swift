import Carbon.HIToolbox
import CoreGraphics
import Foundation
import AppKit
import VoiceScribeCore

final class KeyboardBindingCaptureMonitor {
    private let onCapture: (KeyboardBinding) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onCapture: @escaping (KeyboardBinding) -> Void) {
        self.onCapture = onCapture
    }

    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyboardBindingCaptureMonitor>.fromOpaque(context).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            }, userInfo: context
        ) else { return false }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyDown {
            guard keyCode != Int64(kVK_Escape) else { return nil }
            let modifiers = Self.normalizedModifiers(event.flags)
            onCapture(KeyboardBinding(
                keyCode: keyCode,
                modifiers: modifiers.rawValue,
                displayName: Self.displayName(keyCode: keyCode, modifiers: modifiers)
            ))
            return nil
        }
        if type == .flagsChanged,
           keyCode == Int64(kVK_Function),
           event.flags.contains(.maskSecondaryFn) {
            onCapture(KeyboardBinding(keyCode: keyCode, modifiers: 0, displayName: "Fn"))
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    static func normalizedModifiers(_ flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
    }

    static func displayName(keyCode: Int64, modifiers: CGEventFlags) -> String {
        var prefix = ""
        if modifiers.contains(.maskControl) { prefix += "⌃" }
        if modifiers.contains(.maskAlternate) { prefix += "⌥" }
        if modifiers.contains(.maskShift) { prefix += "⇧" }
        if modifiers.contains(.maskCommand) { prefix += "⌘" }
        return prefix + keyName(keyCode)
    }

    private static func keyName(_ keyCode: Int64) -> String {
        let names: [Int64: String] = [
            Int64(kVK_ANSI_A): "A", Int64(kVK_ANSI_B): "B", Int64(kVK_ANSI_C): "C",
            Int64(kVK_ANSI_D): "D", Int64(kVK_ANSI_E): "E", Int64(kVK_ANSI_F): "F",
            Int64(kVK_ANSI_G): "G", Int64(kVK_ANSI_H): "H", Int64(kVK_ANSI_I): "I",
            Int64(kVK_ANSI_J): "J", Int64(kVK_ANSI_K): "K", Int64(kVK_ANSI_L): "L",
            Int64(kVK_ANSI_M): "M", Int64(kVK_ANSI_N): "N", Int64(kVK_ANSI_O): "O",
            Int64(kVK_ANSI_P): "P", Int64(kVK_ANSI_Q): "Q", Int64(kVK_ANSI_R): "R",
            Int64(kVK_ANSI_S): "S", Int64(kVK_ANSI_T): "T", Int64(kVK_ANSI_U): "U",
            Int64(kVK_ANSI_V): "V", Int64(kVK_ANSI_W): "W", Int64(kVK_ANSI_X): "X",
            Int64(kVK_ANSI_Y): "Y", Int64(kVK_ANSI_Z): "Z",
            Int64(kVK_ANSI_0): "0", Int64(kVK_ANSI_1): "1", Int64(kVK_ANSI_2): "2",
            Int64(kVK_ANSI_3): "3", Int64(kVK_ANSI_4): "4", Int64(kVK_ANSI_5): "5",
            Int64(kVK_ANSI_6): "6", Int64(kVK_ANSI_7): "7", Int64(kVK_ANSI_8): "8",
            Int64(kVK_ANSI_9): "9",
            Int64(kVK_F1): "F1", Int64(kVK_F2): "F2", Int64(kVK_F3): "F3",
            Int64(kVK_F4): "F4", Int64(kVK_F5): "F5", Int64(kVK_F6): "F6",
            Int64(kVK_F7): "F7", Int64(kVK_F8): "F8", Int64(kVK_F9): "F9",
            Int64(kVK_F10): "F10", Int64(kVK_F11): "F11", Int64(kVK_F12): "F12",
            Int64(kVK_Space): "Space", Int64(kVK_Return): "Return", Int64(kVK_Tab): "Tab",
            Int64(kVK_Delete): "Delete", Int64(kVK_ForwardDelete): "Forward Delete",
            Int64(kVK_LeftArrow): "←", Int64(kVK_RightArrow): "→",
            Int64(kVK_UpArrow): "↑", Int64(kVK_DownArrow): "↓"
        ]
        if let name = names[keyCode] { return name }
        if let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true),
           let nsEvent = NSEvent(cgEvent: event),
           let characters = nsEvent.charactersIgnoringModifiers,
           !characters.isEmpty {
            return characters.uppercased()
        }
        return "Key \(keyCode)"
    }

    deinit { stop() }
}
