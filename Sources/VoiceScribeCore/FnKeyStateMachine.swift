import Foundation

public protocol FnKeyScheduler {
    func scheduleAfter(_ delay: TimeInterval, execute: @escaping () -> Void) -> Any
    func cancel(_ token: Any)
}

public final class FnKeyStateMachine {
    private let scheduler: FnKeyScheduler
    private let activationDelay: TimeInterval
    private var onStateChanged: ((Bool) -> Void)?
    private let lock = NSLock()

    private var _fnIsHeld = false
    private var _otherKeyPressedWhileFnHeld = false
    private var _recordingStarted = false
    private var pendingActivation: Any?

    public var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _recordingStarted
    }

    public var isFnHeld: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _fnIsHeld
    }

    public init(activationDelay: TimeInterval = 0.15, scheduler: FnKeyScheduler, onStateChanged: @escaping (Bool) -> Void) {
        self.activationDelay = activationDelay
        self.scheduler = scheduler
        self.onStateChanged = onStateChanged
    }

    public func fnKeyPressed() {
        lock.lock()
        guard !_recordingStarted else {
            lock.unlock()
            return
        }

        _fnIsHeld = true
        _otherKeyPressedWhileFnHeld = false
        lock.unlock()

        pendingActivation = scheduler.scheduleAfter(activationDelay) { [weak self] in
            self?.activateIfValid()
        }
    }

    public func fnKeyReleased() {
        if let token = pendingActivation {
            scheduler.cancel(token)
            pendingActivation = nil
        }

        lock.lock()
        let wasRecording = _recordingStarted
        _fnIsHeld = false
        _otherKeyPressedWhileFnHeld = false
        _recordingStarted = false
        lock.unlock()

        if wasRecording {
            onStateChanged?(false)
        }
    }

    public func otherKeyPressed() {
        lock.lock()
        guard _fnIsHeld else {
            lock.unlock()
            return
        }
        _otherKeyPressedWhileFnHeld = true
        lock.unlock()

        if let token = pendingActivation {
            scheduler.cancel(token)
            pendingActivation = nil
        }
    }

    private func activateIfValid() {
        pendingActivation = nil

        lock.lock()
        let shouldActivate = _fnIsHeld && !_otherKeyPressedWhileFnHeld
        if shouldActivate {
            _recordingStarted = true
        }
        lock.unlock()

        if shouldActivate {
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
