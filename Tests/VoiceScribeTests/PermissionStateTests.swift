import XCTest
@testable import VoiceScribeCore

final class PermissionStateTests: XCTestCase {

    // MARK: - PermissionStatus Tests

    func testPermissionStatusDescriptions() {
        XCTAssertEqual(PermissionStatus.granted.description, "granted")
        XCTAssertEqual(PermissionStatus.denied.description, "denied")
        XCTAssertEqual(PermissionStatus.notDetermined.description, "notDetermined")
        XCTAssertEqual(PermissionStatus.requested.description, "requested")
    }

    func testPermissionStatusIsUsable() {
        XCTAssertTrue(PermissionStatus.granted.isUsable)
        XCTAssertTrue(PermissionStatus.requested.isUsable)
        XCTAssertFalse(PermissionStatus.denied.isUsable)
        XCTAssertFalse(PermissionStatus.notDetermined.isUsable)
    }

    // MARK: - All Permissions Granted (Happy Path)

    func testAllPermissionsGranted() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertTrue(state.allPermissionsGranted)
        XCTAssertTrue(state.isFullyFunctional)
        XCTAssertTrue(state.canRecord)
        XCTAssertTrue(state.canMonitorFnKey)
        XCTAssertTrue(state.canInsertText)
        XCTAssertTrue(state.canDownloadModels)
        XCTAssertTrue(state.missingPermissions.isEmpty)
        XCTAssertTrue(state.blockedPermissions.isEmpty)
        XCTAssertEqual(state.appState, .ready)
    }

    func testAllPermissionsWithRequestedStates() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .requested,
            accessibility: .requested,
            filesAndFolders: .granted
        )

        XCTAssertTrue(state.allPermissionsGranted)
        XCTAssertTrue(state.canRecord)
        XCTAssertTrue(state.canMonitorFnKey)
        XCTAssertTrue(state.canInsertText)
    }

    // MARK: - Microphone Permission Tests

    func testMicrophoneDenied() {
        let state = PermissionState(
            microphone: .denied,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertFalse(state.allPermissionsGranted)
        XCTAssertFalse(state.canRecord)
        XCTAssertTrue(state.canMonitorFnKey)
        XCTAssertTrue(state.canInsertText)
        XCTAssertEqual(state.missingPermissions, ["Microphone"])
        XCTAssertEqual(state.blockedPermissions, ["Microphone"])
        XCTAssertEqual(state.appState, .blocked(permissions: ["Microphone"]))
    }

    func testMicrophoneNotDetermined() {
        let state = PermissionState(
            microphone: .notDetermined,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertFalse(state.allPermissionsGranted)
        XCTAssertFalse(state.canRecord)
        XCTAssertEqual(state.appState, .needsSetup(nextStep: .microphone))
    }

    func testMicrophoneRequestedNotSufficient() {
        let state = PermissionState(
            microphone: .requested,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertFalse(state.canRecord, "Microphone requires .granted, not just .requested")
        XCTAssertFalse(state.allPermissionsGranted)
    }

    // MARK: - Input Monitoring Permission Tests

    func testInputMonitoringDenied() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .denied,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertFalse(state.allPermissionsGranted)
        XCTAssertFalse(state.canMonitorFnKey)
        XCTAssertEqual(state.blockedPermissions, ["Input Monitoring"])
    }

    func testInputMonitoringRequested() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .requested,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertTrue(state.allPermissionsGranted)
        XCTAssertTrue(state.canMonitorFnKey)
    }

    // MARK: - Accessibility Permission Tests

    func testAccessibilityDenied() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .denied,
            filesAndFolders: .granted
        )

        XCTAssertFalse(state.allPermissionsGranted)
        XCTAssertFalse(state.canInsertText)
        XCTAssertEqual(state.blockedPermissions, ["Accessibility"])
    }

    func testAccessibilityRequested() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .requested,
            filesAndFolders: .granted
        )

        XCTAssertTrue(state.allPermissionsGranted)
        XCTAssertTrue(state.canInsertText)
    }

    // MARK: - Files and Folders Permission Tests

    func testFilesAndFoldersDenied() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .denied
        )

        XCTAssertTrue(state.allPermissionsGranted, "Files permission not required for allPermissionsGranted")
        XCTAssertFalse(state.canDownloadModels)
        XCTAssertFalse(state.isFullyFunctional)
        XCTAssertEqual(state.blockedPermissions, ["Files and Folders"])
    }

    func testFilesAndFoldersNotRequired() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .notDetermined
        )

        XCTAssertTrue(state.allPermissionsGranted)
        XCTAssertFalse(state.isFullyFunctional)
    }

    // MARK: - Multiple Permissions Denied

    func testMultiplePermissionsDenied() {
        let state = PermissionState(
            microphone: .denied,
            inputMonitoring: .denied,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertFalse(state.allPermissionsGranted)
        XCTAssertEqual(state.blockedPermissions.count, 2)
        XCTAssertTrue(state.blockedPermissions.contains("Microphone"))
        XCTAssertTrue(state.blockedPermissions.contains("Input Monitoring"))
    }

    func testAllPermissionsDenied() {
        let state = PermissionState(
            microphone: .denied,
            inputMonitoring: .denied,
            accessibility: .denied,
            filesAndFolders: .denied
        )

        XCTAssertFalse(state.allPermissionsGranted)
        XCTAssertFalse(state.canRecord)
        XCTAssertFalse(state.canMonitorFnKey)
        XCTAssertFalse(state.canInsertText)
        XCTAssertFalse(state.canDownloadModels)
        XCTAssertEqual(state.blockedPermissions.count, 4)
        XCTAssertEqual(state.missingPermissions.count, 4)
    }

    // MARK: - Fresh Install State

    func testFreshInstallState() {
        let state = PermissionState()

        XCTAssertEqual(state.microphone, .notDetermined)
        XCTAssertEqual(state.inputMonitoring, .notDetermined)
        XCTAssertEqual(state.accessibility, .notDetermined)
        XCTAssertEqual(state.filesAndFolders, .notDetermined)
        XCTAssertFalse(state.allPermissionsGranted)
        XCTAssertTrue(state.canStartOnboarding)
        XCTAssertTrue(state.canCompleteOnboarding)
        XCTAssertEqual(state.appState, .needsSetup(nextStep: .microphone))
    }

    // MARK: - Onboarding Flow Tests

    func testOnboardingCannotCompleteWithDeniedMicrophone() {
        let state = PermissionState(
            microphone: .denied,
            inputMonitoring: .notDetermined,
            accessibility: .notDetermined,
            filesAndFolders: .notDetermined
        )

        XCTAssertFalse(state.canCompleteOnboarding)
    }

    func testOnboardingCannotCompleteWithDeniedInputMonitoring() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .denied,
            accessibility: .notDetermined,
            filesAndFolders: .notDetermined
        )

        XCTAssertFalse(state.canCompleteOnboarding)
    }

    func testOnboardingCanCompleteWithRequestedPermissions() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .requested,
            accessibility: .requested,
            filesAndFolders: .notDetermined
        )

        XCTAssertTrue(state.canCompleteOnboarding)
    }

    // MARK: - App State Transitions

    func testAppStateNeedsSetupSequence() {
        var state = PermissionState()
        XCTAssertEqual(state.appState, .needsSetup(nextStep: .microphone))

        state.microphone = .granted
        XCTAssertEqual(state.appState, .needsSetup(nextStep: .inputMonitoring))

        state.inputMonitoring = .requested
        XCTAssertEqual(state.appState, .needsSetup(nextStep: .accessibility))

        state.accessibility = .requested
        XCTAssertEqual(state.appState, .needsSetup(nextStep: .filesAndFolders))

        state.filesAndFolders = .granted
        XCTAssertEqual(state.appState, .ready)
    }

    func testAppStateBlockedTakesPrecedence() {
        let state = PermissionState(
            microphone: .denied,
            inputMonitoring: .notDetermined,
            accessibility: .notDetermined,
            filesAndFolders: .notDetermined
        )

        XCTAssertEqual(state.appState, .blocked(permissions: ["Microphone"]))
    }

    // MARK: - Edge Cases

    func testMixedRequestedAndGranted() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .requested,
            accessibility: .granted,
            filesAndFolders: .requested
        )

        XCTAssertTrue(state.allPermissionsGranted)
        XCTAssertFalse(state.isFullyFunctional, "Files .requested means cannot download")
    }

    func testPartialDenialRecovery() {
        var state = PermissionState(
            microphone: .denied,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertEqual(state.appState, .blocked(permissions: ["Microphone"]))

        state.microphone = .granted
        XCTAssertEqual(state.appState, .ready)
    }

    func testPermissionRevocation() {
        var state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertEqual(state.appState, .ready)

        state.accessibility = .denied
        XCTAssertEqual(state.appState, .blocked(permissions: ["Accessibility"]))
    }

    // MARK: - Recording Specific States

    func testCanRecordOnlyWithGrantedMicrophone() {
        let states: [(PermissionStatus, Bool)] = [
            (.granted, true),
            (.denied, false),
            (.notDetermined, false),
            (.requested, false)
        ]

        for (status, expected) in states {
            let state = PermissionState(microphone: status)
            XCTAssertEqual(state.canRecord, expected, "Microphone \(status) should have canRecord=\(expected)")
        }
    }

    func testFnKeyMonitoringWithVariousStates() {
        let states: [(PermissionStatus, Bool)] = [
            (.granted, true),
            (.requested, true),
            (.denied, false),
            (.notDetermined, false)
        ]

        for (status, expected) in states {
            let state = PermissionState(inputMonitoring: status)
            XCTAssertEqual(state.canMonitorFnKey, expected, "Input monitoring \(status) should have canMonitorFnKey=\(expected)")
        }
    }

    func testTextInsertionWithVariousStates() {
        let states: [(PermissionStatus, Bool)] = [
            (.granted, true),
            (.requested, true),
            (.denied, false),
            (.notDetermined, false)
        ]

        for (status, expected) in states {
            let state = PermissionState(accessibility: status)
            XCTAssertEqual(state.canInsertText, expected, "Accessibility \(status) should have canInsertText=\(expected)")
        }
    }

    // MARK: - Functionality Level Tests

    func testFullFunctionality() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertEqual(state.functionalityLevel, .full)
        XCTAssertTrue(state.functionalityLevel.canUseApp)
    }

    func testPartialNoTextInsertion() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .denied,
            filesAndFolders: .granted
        )

        XCTAssertEqual(state.functionalityLevel, .partialNoTextInsertion)
        XCTAssertTrue(state.functionalityLevel.canUseApp)
        XCTAssertTrue(state.canTranscribe)
        XCTAssertFalse(state.canInsertText)
    }

    func testPartialNoModelDownload() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .denied
        )

        XCTAssertEqual(state.functionalityLevel, .partialNoModelDownload)
        XCTAssertTrue(state.functionalityLevel.canUseApp)
        XCTAssertTrue(state.canTranscribe)
        XCTAssertTrue(state.canInsertText)
    }

    func testNonFunctionalMicrophoneDenied() {
        let state = PermissionState(
            microphone: .denied,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertEqual(state.functionalityLevel, .nonFunctional)
        XCTAssertFalse(state.functionalityLevel.canUseApp)
    }

    func testNonFunctionalInputMonitoringDenied() {
        let state = PermissionState(
            microphone: .granted,
            inputMonitoring: .denied,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertEqual(state.functionalityLevel, .nonFunctional)
        XCTAssertFalse(state.functionalityLevel.canUseApp)
    }

    func testFunctionalityLevelDescriptions() {
        XCTAssertTrue(FunctionalityLevel.full.description.contains("Fully"))
        XCTAssertTrue(FunctionalityLevel.partialNoTextInsertion.description.contains("paste"))
        XCTAssertTrue(FunctionalityLevel.partialNoModelDownload.description.contains("download"))
        XCTAssertTrue(FunctionalityLevel.nonFunctional.description.contains("Cannot"))
    }

    func testCanTranscribeRequiresMicAndInput() {
        let working = PermissionState(microphone: .granted, inputMonitoring: .granted)
        XCTAssertTrue(working.canTranscribe)

        let noMic = PermissionState(microphone: .denied, inputMonitoring: .granted)
        XCTAssertFalse(noMic.canTranscribe)

        let noInput = PermissionState(microphone: .granted, inputMonitoring: .denied)
        XCTAssertFalse(noInput.canTranscribe)
    }

    // MARK: - Equality Tests

    func testPermissionStateEquality() {
        let state1 = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        let state2 = PermissionState(
            microphone: .granted,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        let state3 = PermissionState(
            microphone: .denied,
            inputMonitoring: .granted,
            accessibility: .granted,
            filesAndFolders: .granted
        )

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }

    // MARK: - Stress Test: All Combinations

    func testAllPermissionCombinations() {
        let statuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .requested]
        var testedCombinations = 0

        for mic in statuses {
            for input in statuses {
                for acc in statuses {
                    for files in statuses {
                        let state = PermissionState(
                            microphone: mic,
                            inputMonitoring: input,
                            accessibility: acc,
                            filesAndFolders: files
                        )

                        if mic == .granted && (input == .granted || input == .requested) && (acc == .granted || acc == .requested) {
                            XCTAssertTrue(state.allPermissionsGranted, "Should be granted: mic=\(mic), input=\(input), acc=\(acc)")
                        } else {
                            XCTAssertFalse(state.allPermissionsGranted, "Should NOT be granted: mic=\(mic), input=\(input), acc=\(acc)")
                        }

                        testedCombinations += 1
                    }
                }
            }
        }

        XCTAssertEqual(testedCombinations, 256, "Should test 4^4 = 256 combinations")
    }
}
