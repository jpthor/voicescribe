import Carbon.HIToolbox
import CoreGraphics
import Foundation
import VoiceScribeCore

/// Monitors independently enabled keyboard and auxiliary mouse bindings.
final class KeyMouseMonitor {
    private let keyboardBinding: KeyboardBinding?
    private let mouseButtonNumber: Int64?
    private let onStateChanged: (TriggerInputSource, Bool) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyboardIsDown = false
    private var mouseIsDown = false

    init(
        keyboardBinding: KeyboardBinding?,
        mouseButtonNumber: Int64?,
        onStateChanged: @escaping (TriggerInputSource, Bool) -> Void
    ) {
        self.keyboardBinding = keyboardBinding
        self.mouseButtonNumber = mouseButtonNumber
        self.onStateChanged = onStateChanged
    }

    func start() -> Bool {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyMouseMonitor>.fromOpaque(context).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: context
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        keyboardIsDown = false
        mouseIsDown = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passRetained(event)
        }

        if let keyboardBinding {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyboardBinding.keyCode == Int64(kVK_Function), type == .flagsChanged {
                let pressed = event.flags.contains(.maskSecondaryFn)
                if pressed != keyboardIsDown {
                    keyboardIsDown = pressed
                    onStateChanged(.keyboard, pressed)
                }
                return nil
            }
            let modifiers = KeyboardBindingCaptureMonitor.normalizedModifiers(event.flags)
            if (type == .keyDown || type == .keyUp),
               keyCode == keyboardBinding.keyCode,
               modifiers.rawValue == keyboardBinding.modifiers {
                let pressed = type == .keyDown
                if pressed != keyboardIsDown {
                    keyboardIsDown = pressed
                    onStateChanged(.keyboard, pressed)
                }
                return nil
            }
        }

        if let mouseButtonNumber {
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            if (type == .otherMouseDown || type == .otherMouseUp), button == mouseButtonNumber {
                let pressed = type == .otherMouseDown
                if pressed != mouseIsDown {
                    mouseIsDown = pressed
                    onStateChanged(.mouse, pressed)
                }
                return nil
            }
        }
        return Unmanaged.passRetained(event)
    }

    deinit { stop() }
}
