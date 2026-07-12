import CoreGraphics
import Foundation

/// Captures the next auxiliary mouse-button press for binding in Settings.
final class MouseButtonCaptureMonitor {
    private let onCapture: (Int64) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onCapture: @escaping (Int64) -> Void) {
        self.onCapture = onCapture
    }

    func start() -> Bool {
        let eventMask: CGEventMask = 1 << CGEventType.otherMouseDown.rawValue
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<MouseButtonCaptureMonitor>.fromOpaque(context).takeUnretainedValue()
                if type == .otherMouseDown {
                    monitor.onCapture(event.getIntegerValueField(.mouseEventButtonNumber))
                    return nil
                }
                return Unmanaged.passRetained(event)
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

    deinit { stop() }
}
