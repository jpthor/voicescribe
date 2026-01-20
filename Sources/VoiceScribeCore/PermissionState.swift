import Foundation

public enum PermissionStatus: Equatable, CustomStringConvertible {
    case granted
    case denied
    case notDetermined
    case requested

    public var description: String {
        switch self {
        case .granted: return "granted"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .requested: return "requested"
        }
    }

    public var isUsable: Bool {
        self == .granted || self == .requested
    }
}

public struct PermissionState: Equatable {
    public var microphone: PermissionStatus
    public var inputMonitoring: PermissionStatus
    public var accessibility: PermissionStatus
    public var filesAndFolders: PermissionStatus

    public init(
        microphone: PermissionStatus = .notDetermined,
        inputMonitoring: PermissionStatus = .notDetermined,
        accessibility: PermissionStatus = .notDetermined,
        filesAndFolders: PermissionStatus = .notDetermined
    ) {
        self.microphone = microphone
        self.inputMonitoring = inputMonitoring
        self.accessibility = accessibility
        self.filesAndFolders = filesAndFolders
    }

    public var canRecord: Bool {
        microphone == .granted
    }

    public var canMonitorFnKey: Bool {
        inputMonitoring == .granted || inputMonitoring == .requested
    }

    public var canInsertText: Bool {
        accessibility == .granted || accessibility == .requested
    }

    public var canDownloadModels: Bool {
        filesAndFolders == .granted
    }

    public var allPermissionsGranted: Bool {
        microphone == .granted &&
        (inputMonitoring == .granted || inputMonitoring == .requested) &&
        (accessibility == .granted || accessibility == .requested)
    }

    public var isFullyFunctional: Bool {
        canRecord && canMonitorFnKey && canInsertText && canDownloadModels
    }

    public var canTranscribe: Bool {
        canRecord && canMonitorFnKey
    }

    public var functionalityLevel: FunctionalityLevel {
        if !canRecord || !canMonitorFnKey {
            return .nonFunctional
        }
        if !canInsertText {
            return .partialNoTextInsertion
        }
        if !canDownloadModels {
            return .partialNoModelDownload
        }
        return .full
    }

    public var missingPermissions: [String] {
        var missing: [String] = []
        if !canRecord { missing.append("Microphone") }
        if !canMonitorFnKey { missing.append("Input Monitoring") }
        if !canInsertText { missing.append("Accessibility") }
        if !canDownloadModels { missing.append("Files and Folders") }
        return missing
    }

    public var blockedPermissions: [String] {
        var blocked: [String] = []
        if microphone == .denied { blocked.append("Microphone") }
        if inputMonitoring == .denied { blocked.append("Input Monitoring") }
        if accessibility == .denied { blocked.append("Accessibility") }
        if filesAndFolders == .denied { blocked.append("Files and Folders") }
        return blocked
    }

    public var canStartOnboarding: Bool {
        true
    }

    public var canCompleteOnboarding: Bool {
        microphone != .denied &&
        inputMonitoring != .denied &&
        accessibility != .denied
    }

    public var appState: AppPermissionState {
        if isFullyFunctional {
            return .ready
        }

        if !blockedPermissions.isEmpty {
            return .blocked(permissions: blockedPermissions)
        }

        if microphone == .notDetermined {
            return .needsSetup(nextStep: .microphone)
        }

        if inputMonitoring == .notDetermined || inputMonitoring == .denied {
            return .needsSetup(nextStep: .inputMonitoring)
        }

        if accessibility == .notDetermined || accessibility == .denied {
            return .needsSetup(nextStep: .accessibility)
        }

        if filesAndFolders == .notDetermined || filesAndFolders == .denied {
            return .needsSetup(nextStep: .filesAndFolders)
        }

        return .ready
    }
}

public enum AppPermissionState: Equatable {
    case ready
    case needsSetup(nextStep: PermissionType)
    case blocked(permissions: [String])
}

public enum PermissionType: String, CaseIterable {
    case microphone = "Microphone"
    case inputMonitoring = "Input Monitoring"
    case accessibility = "Accessibility"
    case filesAndFolders = "Files and Folders"
}

public enum FunctionalityLevel: Equatable, CustomStringConvertible {
    case full
    case partialNoTextInsertion
    case partialNoModelDownload
    case nonFunctional

    public var description: String {
        switch self {
        case .full:
            return "Fully functional"
        case .partialNoTextInsertion:
            return "Can transcribe but cannot auto-paste (copy manually from menu)"
        case .partialNoModelDownload:
            return "Working but cannot download new models"
        case .nonFunctional:
            return "Cannot function - missing critical permissions"
        }
    }

    public var canUseApp: Bool {
        self != .nonFunctional
    }
}
