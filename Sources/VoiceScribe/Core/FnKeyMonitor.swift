import Foundation
import IOKit
import IOKit.hid
import VoiceScribeCore

final class FnKeyMonitor {
    private var hidManager: IOHIDManager?
    private let inputHandler: HIDInputHandler

    init(onFnKeyStateChanged: @escaping (Bool) -> Void) {
        let stateMachine = FnKeyStateMachine(
            scheduler: DispatchQueueScheduler(),
            onStateChanged: onFnKeyStateChanged
        )
        self.inputHandler = HIDInputHandler(stateMachine: stateMachine)
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

        let event = HIDKeyEvent(
            usagePage: usagePage,
            usage: usage,
            value: Int(intValue)
        )
        inputHandler.handleKeyEvent(event)
    }

    deinit {
        stop()
    }
}
