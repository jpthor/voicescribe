import XCTest
@testable import VoiceScribeCore

final class HIDInputHandlerTests: XCTestCase {

    // MARK: - Test Helpers

    final class MockScheduler: FnKeyScheduler {
        var pendingBlocks: [() -> Void] = []

        func scheduleAfter(_ delay: TimeInterval, execute: @escaping () -> Void) -> Any {
            pendingBlocks.append(execute)
            return pendingBlocks.count - 1
        }

        func cancel(_ token: Any) {
            if let index = token as? Int, index < pendingBlocks.count {
                pendingBlocks[index] = {}
            }
        }

        func executeAll() {
            let blocks = pendingBlocks
            pendingBlocks.removeAll()
            blocks.forEach { $0() }
        }
    }

    final class SynchronousDispatcher: MainThreadDispatcher {
        var dispatchedBlocks: [() -> Void] = []
        var executeImmediately = true

        func dispatch(_ block: @escaping () -> Void) {
            if executeImmediately {
                block()
            } else {
                dispatchedBlocks.append(block)
            }
        }

        func executeAll() {
            let blocks = dispatchedBlocks
            dispatchedBlocks.removeAll()
            blocks.forEach { $0() }
        }
    }

    final class ThreadTrackingDispatcher: MainThreadDispatcher {
        var dispatchCalledFromMainThread: Bool?
        var blockExecutedOnMainThread: Bool?
        private let executeImmediately: Bool

        init(executeImmediately: Bool = true) {
            self.executeImmediately = executeImmediately
        }

        func dispatch(_ block: @escaping () -> Void) {
            dispatchCalledFromMainThread = Thread.isMainThread
            if executeImmediately {
                blockExecutedOnMainThread = Thread.isMainThread
                block()
            }
        }
    }

    // MARK: - Basic Fn Key Tests

    func testFnKeyPressTriggersStateMachine() {
        var stateChanges: [Bool] = []
        let scheduler = MockScheduler()
        let dispatcher = SynchronousDispatcher()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        let fnPressEvent = HIDKeyEvent(
            usagePage: HIDInputHandler.fnUsagePage,
            usage: HIDInputHandler.fnUsage,
            value: 1
        )
        handler.handleKeyEvent(fnPressEvent)
        scheduler.executeAll()

        XCTAssertTrue(stateMachine.isFnHeld)
        XCTAssertEqual(stateChanges, [true])
    }

    func testFnKeyReleaseTriggersStateMachine() {
        var stateChanges: [Bool] = []
        let scheduler = MockScheduler()
        let dispatcher = SynchronousDispatcher()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        // Press Fn
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.fnUsagePage,
            usage: HIDInputHandler.fnUsage,
            value: 1
        ))
        scheduler.executeAll()

        // Release Fn
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.fnUsagePage,
            usage: HIDInputHandler.fnUsage,
            value: 0
        ))

        XCTAssertFalse(stateMachine.isFnHeld)
        XCTAssertEqual(stateChanges, [true, false])
    }

    func testOtherKeyWhileFnHeldCancelsRecording() {
        var stateChanges: [Bool] = []
        let scheduler = MockScheduler()
        let dispatcher = SynchronousDispatcher()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        // Press Fn (but don't execute scheduler yet - simulating delay)
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.fnUsagePage,
            usage: HIDInputHandler.fnUsage,
            value: 1
        ))

        // Press another key before activation delay
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.keyboardUsagePage,
            usage: 0x04, // 'A' key
            value: 1
        ))

        // Now execute pending activation - should be cancelled
        scheduler.executeAll()

        XCTAssertTrue(stateChanges.isEmpty, "Recording should not have started")
    }

    func testOtherKeyIgnoredWhenFnNotHeld() {
        var stateChanges: [Bool] = []
        let scheduler = MockScheduler()
        let dispatcher = SynchronousDispatcher()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        // Press a key without Fn held
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.keyboardUsagePage,
            usage: 0x04,
            value: 1
        ))

        XCTAssertTrue(stateChanges.isEmpty)
        XCTAssertFalse(stateMachine.isFnHeld)
    }

    // MARK: - Thread Safety Tests

    func testFnKeyEventDispatchesToMainThread() {
        let scheduler = MockScheduler()
        let dispatcher = ThreadTrackingDispatcher()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { _ in }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.fnUsagePage,
            usage: HIDInputHandler.fnUsage,
            value: 1
        ))

        XCTAssertNotNil(dispatcher.dispatchCalledFromMainThread, "Dispatch should have been called")
    }

    func testOtherKeyEventDispatchesToMainThread() {
        let scheduler = MockScheduler()
        let dispatcher = SynchronousDispatcher()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { _ in }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        // First press Fn to set isFnHeld
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.fnUsagePage,
            usage: HIDInputHandler.fnUsage,
            value: 1
        ))
        scheduler.executeAll()

        // Now use thread tracking dispatcher for other key
        let trackingDispatcher = ThreadTrackingDispatcher()
        let handler2 = HIDInputHandler(stateMachine: stateMachine, dispatcher: trackingDispatcher)

        handler2.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.keyboardUsagePage,
            usage: 0x04,
            value: 1
        ))

        XCTAssertNotNil(trackingDispatcher.dispatchCalledFromMainThread, "Dispatch should have been called")
    }

    func testIsFnHeldCheckHappensInsideDispatch() {
        // This test verifies the thread safety fix:
        // The isFnHeld check must happen INSIDE the dispatch block, not outside.
        // If it happened outside, a race condition could cause a crash.

        let scheduler = MockScheduler()
        let dispatcher = SynchronousDispatcher()
        dispatcher.executeImmediately = false

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0.15, // Use delay so recording doesn't start immediately
            scheduler: scheduler,
            onStateChanged: { _ in }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        // Send other key event when Fn is NOT held
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.keyboardUsagePage,
            usage: 0x04,
            value: 1
        ))

        // Block is queued but not executed yet
        XCTAssertEqual(dispatcher.dispatchedBlocks.count, 1)

        // Now press Fn (simulating a race condition where Fn is pressed
        // after other key event was sent but before dispatch executed)
        let fnDispatcher = SynchronousDispatcher()
        let fnHandler = HIDInputHandler(stateMachine: stateMachine, dispatcher: fnDispatcher)
        fnHandler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.fnUsagePage,
            usage: HIDInputHandler.fnUsage,
            value: 1
        ))

        // Now Fn is held (but recording not started yet due to delay)
        XCTAssertTrue(stateMachine.isFnHeld)
        XCTAssertFalse(stateMachine.isRecording)

        // Execute the queued other key block - it should now see isFnHeld as true
        // and call otherKeyPressed, which cancels the pending activation
        dispatcher.executeAll()

        // Now execute the scheduler - the activation should have been cancelled
        scheduler.executeAll()

        // Recording should NOT have started because other key cancelled it
        // (if isFnHeld check was outside dispatch, it would have seen false and not cancelled)
        XCTAssertFalse(stateMachine.isRecording, "Recording should be cancelled by other key")
    }

    func testConcurrentEventsFromBackgroundThread() {
        let expectation = XCTestExpectation(description: "Background events processed")
        var stateChanges: [Bool] = []
        let scheduler = MockScheduler()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine)

        // Simulate HID callback from background thread
        DispatchQueue.global(qos: .userInteractive).async {
            handler.handleKeyEvent(HIDKeyEvent(
                usagePage: HIDInputHandler.fnUsagePage,
                usage: HIDInputHandler.fnUsage,
                value: 1
            ))

            // Small delay to ensure dispatch happens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scheduler.executeAll()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(stateMachine.isFnHeld)
        XCTAssertEqual(stateChanges, [true])
    }

    func testRapidConcurrentEvents() {
        let expectation = XCTestExpectation(description: "Rapid events processed")
        var stateChanges: [Bool] = []
        let scheduler = MockScheduler()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine)

        let iterations = 100
        let group = DispatchGroup()

        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                handler.handleKeyEvent(HIDKeyEvent(
                    usagePage: HIDInputHandler.fnUsagePage,
                    usage: HIDInputHandler.fnUsage,
                    value: i % 2 // alternating press/release
                ))
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // Give time for all dispatches to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                scheduler.executeAll()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Should not crash - that's the main test
        // State should be consistent (final state depends on order, but no crash)
    }

    // MARK: - Edge Cases

    func testKeyReleaseEventIgnored() {
        let scheduler = MockScheduler()
        let dispatcher = SynchronousDispatcher()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { _ in }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        // Press Fn first
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.fnUsagePage,
            usage: HIDInputHandler.fnUsage,
            value: 1
        ))
        scheduler.executeAll()

        XCTAssertTrue(stateMachine.isFnHeld)

        // Other key release (value: 0) should be ignored
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: HIDInputHandler.keyboardUsagePage,
            usage: 0x04,
            value: 0
        ))

        // Still recording (other key release didn't cancel it)
        XCTAssertTrue(stateMachine.isRecording)
    }

    func testNonKeyboardEventsIgnored() {
        var stateChanges: [Bool] = []
        let scheduler = MockScheduler()
        let dispatcher = SynchronousDispatcher()

        let stateMachine = FnKeyStateMachine(
            activationDelay: 0,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )
        let handler = HIDInputHandler(stateMachine: stateMachine, dispatcher: dispatcher)

        // Random usage page that's not Fn or keyboard
        handler.handleKeyEvent(HIDKeyEvent(
            usagePage: 0x01, // Generic Desktop
            usage: 0x30, // X axis
            value: 100
        ))

        XCTAssertTrue(stateChanges.isEmpty)
        XCTAssertFalse(stateMachine.isFnHeld)
    }
}
