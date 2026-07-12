public enum TriggerSignal {
    case pressed
    case released
}

public enum TriggerPhase {
    case idle
    case recording
    case busy
}

public enum TriggerAction: Equatable {
    case start
    case transcribe
}

public enum TriggerInteraction {
    public static func action(
        mode: TriggerMode,
        signal: TriggerSignal,
        phase: TriggerPhase
    ) -> TriggerAction? {
        switch (mode, signal, phase) {
        case (.hold, .pressed, .idle):
            return .start
        case (.hold, .released, .recording):
            return .transcribe
        case (.toggle, .pressed, .idle):
            return .start
        case (.toggle, .pressed, .recording):
            return .transcribe
        default:
            return nil
        }
    }
}
