import Foundation

public protocol MainThreadDispatcher {
    func dispatch(_ block: @escaping () -> Void)
}

public final class GCDMainThreadDispatcher: MainThreadDispatcher {
    public init() {}

    public func dispatch(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}

public struct HIDKeyEvent {
    public let usagePage: UInt32
    public let usage: UInt32
    public let value: Int

    public init(usagePage: UInt32, usage: UInt32, value: Int) {
        self.usagePage = usagePage
        self.usage = usage
        self.value = value
    }
}

public final class HIDInputHandler {
    public static let fnUsagePage: UInt32 = 0xFF
    public static let fnUsage: UInt32 = 0x03
    public static let keyboardUsagePage: UInt32 = 0x07

    private let stateMachine: FnKeyStateMachine
    private let dispatcher: MainThreadDispatcher

    public init(stateMachine: FnKeyStateMachine, dispatcher: MainThreadDispatcher = GCDMainThreadDispatcher()) {
        self.stateMachine = stateMachine
        self.dispatcher = dispatcher
    }

    public func handleKeyEvent(_ event: HIDKeyEvent) {
        if event.usagePage == Self.fnUsagePage && event.usage == Self.fnUsage {
            let pressed = event.value == 1
            dispatcher.dispatch { [weak self] in
                guard let self = self else { return }
                if pressed {
                    self.stateMachine.fnKeyPressed()
                } else {
                    self.stateMachine.fnKeyReleased()
                }
            }
        } else if event.usagePage == Self.keyboardUsagePage && event.value == 1 {
            dispatcher.dispatch { [weak self] in
                guard let self = self, self.stateMachine.isFnHeld else { return }
                self.stateMachine.otherKeyPressed()
            }
        }
    }
}
