import Foundation
import IOKit
import IOKit.hid
import VoiceScribeCore

final class FnKeyMonitor {
    private var hidManager: IOHIDManager?
    private let stateMachine: FnKeyStateMachine

    private static let fnUsagePage: UInt32 = 0xFF
    private static let fnUsage: UInt32 = 0x03

    init(onFnKeyStateChanged: @escaping (Bool) -> Void) {
        self.stateMachine = FnKeyStateMachine(
            scheduler: DispatchQueueScheduler(),
            onStateChanged: onFnKeyStateChanged
        )
    }

    func start() -> Bool {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else {
            return false
        }

        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            guard let context = context else { return }
            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handleInputValue(value)
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            return false
        }

        return true
    }

    func stop() {
        guard let manager = hidManager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = nil
    }

    private func handleInputValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)

        if usagePage == Self.fnUsagePage && usage == Self.fnUsage {
            let pressed = intValue == 1
            DispatchQueue.main.async { [weak self] in
                if pressed {
                    self?.stateMachine.fnKeyPressed()
                } else {
                    self?.stateMachine.fnKeyReleased()
                }
            }
        } else if stateMachine.isFnHeld && usagePage == kHIDPage_KeyboardOrKeypad && intValue == 1 {
            DispatchQueue.main.async { [weak self] in
                self?.stateMachine.otherKeyPressed()
            }
        }
    }

    deinit {
        stop()
    }
}
