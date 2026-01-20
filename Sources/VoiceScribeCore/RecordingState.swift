import Foundation

public enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case error(String)

    public var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    public var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    public var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }

    public var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}
