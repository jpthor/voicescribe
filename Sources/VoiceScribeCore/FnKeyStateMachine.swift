import Foundation

public protocol FnKeyScheduler {
    func scheduleAfter(_ delay: TimeInterval, execute: @escaping () -> Void) -> Any
    func cancel(_ token: Any)
}

public final class FnKeyStateMachine {
    private let scheduler: FnKeyScheduler
    private let activationDelay: TimeInterval
    private var onStateChanged: ((Bool) -> Void)?

    private var fnIsHeld = false
    private var otherKeyPressedWhileFnHeld = false
    private var recordingStarted = false
    private var pendingActivation: Any?

    public var isRecording: Bool { recordingStarted }
    public var isFnHeld: Bool { fnIsHeld }

    public init(activationDelay: TimeInterval = 0.15, scheduler: FnKeyScheduler, onStateChanged: @escaping (Bool) -> Void) {
        self.activationDelay = activationDelay
        self.scheduler = scheduler
        self.onStateChanged = onStateChanged
    }

    public func fnKeyPressed() {
        guard !recordingStarted else { return }

        fnIsHeld = true
        otherKeyPressedWhileFnHeld = false

        pendingActivation = scheduler.scheduleAfter(activationDelay) { [weak self] in
            self?.activateIfValid()
        }
    }

    public func fnKeyReleased() {
        if let token = pendingActivation {
            scheduler.cancel(token)
            pendingActivation = nil
        }

        if recordingStarted {
            onStateChanged?(false)
        }

        fnIsHeld = false
        otherKeyPressedWhileFnHeld = false
        recordingStarted = false
    }

    public func otherKeyPressed() {
        guard fnIsHeld else { return }

        otherKeyPressedWhileFnHeld = true

        if let token = pendingActivation {
            scheduler.cancel(token)
            pendingActivation = nil
        }
    }

    private func activateIfValid() {
        pendingActivation = nil

        if fnIsHeld && !otherKeyPressedWhileFnHeld {
            recordingStarted = true
            onStateChanged?(true)
        }
    }
}

public final class DispatchQueueScheduler: FnKeyScheduler {
    public init() {}

    public func scheduleAfter(_ delay: TimeInterval, execute: @escaping () -> Void) -> Any {
        let workItem = DispatchWorkItem(block: execute)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        return workItem
    }

    public func cancel(_ token: Any) {
        (token as? DispatchWorkItem)?.cancel()
    }
}
