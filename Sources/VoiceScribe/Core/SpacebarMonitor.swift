import Foundation
import CoreGraphics
import Carbon.HIToolbox
import VoiceScribeCore

/// Monitors spacebar press/release via CGEventTap.
/// Suppresses the space character during recording and synthesises
/// a normal space for quick taps (< activationDelay).
final class SpacebarMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onKeyStateChanged: (Bool) -> Void
    private let triggerMode: TriggerMode

    /// Sentinel value on synthesised events so we don't re-intercept them.
    private static let sentinelTag: Int64 = 0x56_53  // "VS"

    private let activationDelay: TimeInterval = 0.3
    private var isHeld = false
    private var activated = false
    private var activationTimer: DispatchWorkItem?

    init(triggerMode: TriggerMode, onKeyStateChanged: @escaping (Bool) -> Void) {
        self.triggerMode = triggerMode
        self.onKeyStateChanged = onKeyStateChanged
    }

    func start() -> Bool {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, ctx -> Unmanaged<CGEvent>? in
                guard let ctx = ctx else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<SpacebarMonitor>.fromOpaque(ctx).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: context
        ) else {
            return false
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        activationTimer?.cancel()
        activationTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isHeld = false
        activated = false
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if macOS disabled it (happens on timeout)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(kVK_Space) else {
            return Unmanaged.passRetained(event)
        }

        // Let our own synthesised events pass through
        if event.getIntegerValueField(.eventSourceUserData) == Self.sentinelTag {
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            return handleSpaceDown(event: event)
        } else if type == .keyUp {
            return handleSpaceUp(event: event)
        }

        return Unmanaged.passRetained(event)
    }

    private func handleSpaceDown(event: CGEvent) -> Unmanaged<CGEvent>? {
        if isHeld {
            // Key repeat while held — suppress
            return nil
        }

        isHeld = true
        activated = false

        if triggerMode == .toggle {
            activated = true
            onKeyStateChanged(true)
            return nil
        }

        // Schedule activation
        let timer = DispatchWorkItem { [weak self] in
            self?.activate()
        }
        activationTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay, execute: timer)

        // Suppress the key-down; we'll synthesise a space if it was a quick tap
        return nil
    }

    private func handleSpaceUp(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isHeld else {
            return Unmanaged.passRetained(event)
        }

        isHeld = false
        activationTimer?.cancel()
        activationTimer = nil

        if activated {
            // Hold mode stops on release. Toggle mode stops on the next press.
            activated = false
            if triggerMode == .hold {
                onKeyStateChanged(false)
            }
            return nil
        } else {
            // Quick tap — synthesise a normal space character
            synthesiseSpace()
            return nil
        }
    }

    private func activate() {
        guard isHeld else { return }
        activated = true
        onKeyStateChanged(true)
    }

    private func synthesiseSpace() {
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Space), keyDown: true),
           let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Space), keyDown: false) {
            down.setIntegerValueField(.eventSourceUserData, value: Self.sentinelTag)
            up.setIntegerValueField(.eventSourceUserData, value: Self.sentinelTag)
            down.post(tap: .cgAnnotatedSessionEventTap)
            up.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    deinit {
        stop()
    }
}
