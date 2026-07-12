import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Consumes Escape only when it actually cancels an active recording.
final class EscapeKeyMonitor {
    private let onEscape: () -> Bool
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onEscape: @escaping () -> Bool) {
        self.onEscape = onEscape
    }

    func start() -> Bool {
        let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<EscapeKeyMonitor>.fromOpaque(context).takeUnretainedValue()
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
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passRetained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyDown && keyCode == Int64(kVK_Escape) && onEscape() {
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    deinit { stop() }
}
