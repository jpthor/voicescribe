import XCTest
@testable import VoiceScribeCore

final class MockScheduler: FnKeyScheduler {
    private var nextToken = 0
    private var pendingBlocks: [Int: () -> Void] = [:]

    func scheduleAfter(_ delay: TimeInterval, execute: @escaping () -> Void) -> Any {
        let token = nextToken
        nextToken += 1
        pendingBlocks[token] = execute
        return token
    }

    func cancel(_ token: Any) {
        guard let intToken = token as? Int else { return }
        pendingBlocks.removeValue(forKey: intToken)
    }

    func firePending() {
        let blocks = pendingBlocks
        pendingBlocks.removeAll()
        for (_, block) in blocks {
            block()
        }
    }

    var hasPendingWork: Bool {
        !pendingBlocks.isEmpty
    }
}

final class FnKeyStateMachineTests: XCTestCase {

    func testFnHeldAloneTriggersRecording() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        XCTAssertTrue(scheduler.hasPendingWork)
        XCTAssertEqual(stateChanges, [])

        scheduler.firePending()
        XCTAssertEqual(stateChanges, [true])
        XCTAssertTrue(sm.isRecording)

        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [true, false])
        XCTAssertFalse(sm.isRecording)
    }

    func testFnWithOtherKeyDoesNotTriggerRecording() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        XCTAssertTrue(scheduler.hasPendingWork)

        sm.otherKeyPressed()
        XCTAssertFalse(scheduler.hasPendingWork)

        scheduler.firePending()
        XCTAssertEqual(stateChanges, [])

        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [])
        XCTAssertFalse(sm.isRecording)
    }

    func testFnReleasedBeforeDelayDoesNotTriggerRecording() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        XCTAssertTrue(scheduler.hasPendingWork)

        sm.fnKeyReleased()
        XCTAssertFalse(scheduler.hasPendingWork)

        scheduler.firePending()
        XCTAssertEqual(stateChanges, [])
    }

    func testOtherKeyPressedAfterRecordingStartedStillRecords() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        scheduler.firePending()
        XCTAssertEqual(stateChanges, [true])
        XCTAssertTrue(sm.isRecording)

        sm.otherKeyPressed()
        XCTAssertTrue(sm.isRecording)

        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [true, false])
    }

    func testMultipleFnPressReleaseCycles() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        sm.otherKeyPressed()
        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [])

        sm.fnKeyPressed()
        scheduler.firePending()
        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [true, false])

        sm.fnKeyPressed()
        sm.otherKeyPressed()
        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [true, false])
    }

    func testOtherKeyBeforeFnHeldIsIgnored() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.otherKeyPressed()

        sm.fnKeyPressed()
        scheduler.firePending()
        XCTAssertEqual(stateChanges, [true])

        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [true, false])
    }

    func testForwardDeleteScenario() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        sm.otherKeyPressed()
        sm.fnKeyReleased()

        XCTAssertEqual(stateChanges, [], "Forward delete (Fn+Delete) should not trigger recording")
    }

    func testRapidFnTapDoesNotTrigger() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        sm.fnKeyReleased()

        XCTAssertEqual(stateChanges, [], "Quick Fn tap should not trigger recording")
    }

    func testDoublePressDuringRecording() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        scheduler.firePending()
        XCTAssertTrue(sm.isRecording)

        sm.fnKeyPressed()
        XCTAssertTrue(sm.isRecording)

        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [true, false])
    }

    func testMultipleOtherKeyPresses() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        sm.otherKeyPressed()
        sm.otherKeyPressed()
        sm.otherKeyPressed()
        sm.fnKeyReleased()

        XCTAssertEqual(stateChanges, [])
    }

    func testReleaseWithoutPress() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyReleased()

        XCTAssertEqual(stateChanges, [])
        XCTAssertFalse(sm.isFnHeld)
        XCTAssertFalse(sm.isRecording)
    }

    func testCustomActivationDelay() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.5,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        XCTAssertTrue(scheduler.hasPendingWork)

        scheduler.firePending()
        XCTAssertEqual(stateChanges, [true])
    }

    func testStateAfterErrorRecovery() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        sm.otherKeyPressed()
        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [])

        sm.fnKeyPressed()
        scheduler.firePending()
        XCTAssertEqual(stateChanges, [true])

        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [true, false])

        sm.fnKeyPressed()
        scheduler.firePending()
        sm.fnKeyReleased()
        XCTAssertEqual(stateChanges, [true, false, true, false])
    }

    func testConcurrentOtherKeyAndRelease() {
        let scheduler = MockScheduler()
        var stateChanges: [Bool] = []

        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { stateChanges.append($0) }
        )

        sm.fnKeyPressed()
        scheduler.firePending()
        XCTAssertTrue(sm.isRecording)

        sm.otherKeyPressed()
        sm.fnKeyReleased()

        XCTAssertEqual(stateChanges, [true, false])
    }

    func testIsFnHeldTracking() {
        let scheduler = MockScheduler()
        let sm = FnKeyStateMachine(
            activationDelay: 0.15,
            scheduler: scheduler,
            onStateChanged: { _ in }
        )

        XCTAssertFalse(sm.isFnHeld)

        sm.fnKeyPressed()
        XCTAssertTrue(sm.isFnHeld)

        sm.fnKeyReleased()
        XCTAssertFalse(sm.isFnHeld)
    }
}
