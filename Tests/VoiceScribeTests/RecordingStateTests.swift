import XCTest
@testable import VoiceScribeCore

final class RecordingStateTests: XCTestCase {

    func testIdleState() {
        let state = RecordingState.idle

        XCTAssertTrue(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isProcessing)
        XCTAssertFalse(state.isError)
        XCTAssertNil(state.errorMessage)
    }

    func testRecordingState() {
        let state = RecordingState.recording

        XCTAssertFalse(state.isIdle)
        XCTAssertTrue(state.isRecording)
        XCTAssertFalse(state.isProcessing)
        XCTAssertFalse(state.isError)
        XCTAssertNil(state.errorMessage)
    }

    func testProcessingState() {
        let state = RecordingState.processing

        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertTrue(state.isProcessing)
        XCTAssertFalse(state.isError)
        XCTAssertNil(state.errorMessage)
    }

    func testErrorState() {
        let errorMessage = "Test error message"
        let state = RecordingState.error(errorMessage)

        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isProcessing)
        XCTAssertTrue(state.isError)
        XCTAssertEqual(state.errorMessage, errorMessage)
    }

    func testEquality() {
        XCTAssertEqual(RecordingState.idle, RecordingState.idle)
        XCTAssertEqual(RecordingState.recording, RecordingState.recording)
        XCTAssertEqual(RecordingState.processing, RecordingState.processing)
        XCTAssertEqual(RecordingState.error("test"), RecordingState.error("test"))

        XCTAssertNotEqual(RecordingState.idle, RecordingState.recording)
        XCTAssertNotEqual(RecordingState.error("a"), RecordingState.error("b"))
    }

    func testErrorWithEmptyMessage() {
        let state = RecordingState.error("")

        XCTAssertTrue(state.isError)
        XCTAssertEqual(state.errorMessage, "")
    }
}
