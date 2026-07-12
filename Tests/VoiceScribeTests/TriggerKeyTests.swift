import XCTest
@testable import VoiceScribeCore

final class TriggerKeyTests: XCTestCase {
    func testDefaultKeyboardBindingIsF5() {
        XCTAssertEqual(KeyboardBinding.f5.keyCode, 96)
        XCTAssertEqual(KeyboardBinding.f5.modifiers, 0)
        XCTAssertEqual(KeyboardBinding.f5.displayName, "F5")
    }
    func testAllTriggerSourcesAreAvailable() {
        XCTAssertEqual(TriggerKey.allCases, [.fn, .f5, .spacebar, .mouse])
    }

    func testTriggerSourceLabels() {
        XCTAssertEqual(TriggerKey.fn.displayName, "Fn")
        XCTAssertEqual(TriggerKey.f5.displayName, "F5")
        XCTAssertEqual(TriggerKey.spacebar.displayName, "Spacebar")
        XCTAssertEqual(TriggerKey.mouse.displayName, "Mouse Button")
    }

    func testHoldAndToggleModesAreAvailable() {
        XCTAssertEqual(TriggerMode.allCases, [.hold, .toggle])
        XCTAssertEqual(TriggerMode.hold.displayName, "Hold")
        XCTAssertEqual(TriggerMode.toggle.displayName, "Toggle")
    }

    func testHoldModeStartsOnPressAndTranscribesOnRelease() {
        XCTAssertEqual(
            TriggerInteraction.action(mode: .hold, signal: .pressed, phase: .idle),
            .start
        )
        XCTAssertEqual(
            TriggerInteraction.action(mode: .hold, signal: .released, phase: .recording),
            .transcribe
        )
        XCTAssertNil(
            TriggerInteraction.action(mode: .hold, signal: .released, phase: .idle)
        )
    }

    func testToggleModeUsesPressForStartAndStop() {
        XCTAssertEqual(
            TriggerInteraction.action(mode: .toggle, signal: .pressed, phase: .idle),
            .start
        )
        XCTAssertEqual(
            TriggerInteraction.action(mode: .toggle, signal: .pressed, phase: .recording),
            .transcribe
        )
        XCTAssertNil(
            TriggerInteraction.action(mode: .toggle, signal: .released, phase: .recording)
        )
    }

    func testTriggerDoesNothingWhileProcessing() {
        for mode in TriggerMode.allCases {
            XCTAssertNil(
                TriggerInteraction.action(mode: mode, signal: .pressed, phase: .busy)
            )
        }
    }
}
