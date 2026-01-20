import AVFAudio
import AVFoundation
import AppKit
import IOKit.hid
import VoiceScribeCore

func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let msg = "[\(timestamp)] \(message)"
    print(msg)
    NSLog("%@", msg)
}

@MainActor
final class PermissionManager: ObservableObject {
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var inputMonitoringStatus: PermissionStatus = .notDetermined
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    @Published var filesAndFoldersStatus: PermissionStatus = .notDetermined

    var inputMonitoringRequested: Bool {
        UserDefaults.standard.bool(forKey: "inputMonitoringRequested")
    }

    var accessibilityRequested: Bool {
        UserDefaults.standard.bool(forKey: "accessibilityRequested")
    }

    var allPermissionsGranted: Bool {
        microphoneStatus == .granted &&
        (inputMonitoringStatus == .granted || inputMonitoringStatus == .requested) &&
        (accessibilityStatus == .granted || accessibilityStatus == .requested)
    }

    func checkAllPermissions() {
        log("checkAllPermissions called")
        checkMicrophonePermission()
        checkInputMonitoringPermission()
        checkAccessibilityPermission()
        checkFilesAndFoldersPermission()
        log("checkAllPermissions completed")
    }

    func checkMicrophonePermission() {
        log("checkMicrophonePermission called")
        if #available(macOS 14.0, *) {
            let recordPermission = AVAudioApplication.shared.recordPermission
            log("Microphone recordPermission: \(recordPermission.rawValue)")
            switch recordPermission {
            case .granted:
                microphoneStatus = .granted
                log("Microphone: granted")
            case .denied:
                microphoneStatus = .denied
                log("Microphone: denied")
            case .undetermined:
                microphoneStatus = .notDetermined
                log("Microphone: notDetermined")
            @unknown default:
                microphoneStatus = .notDetermined
                log("Microphone: unknown")
            }
        } else {
            let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            log("Microphone authStatus: \(authStatus.rawValue)")
            switch authStatus {
            case .authorized:
                microphoneStatus = .granted
                log("Microphone: granted")
            case .denied, .restricted:
                microphoneStatus = .denied
                log("Microphone: denied")
            case .notDetermined:
                microphoneStatus = .notDetermined
                log("Microphone: notDetermined")
            @unknown default:
                microphoneStatus = .notDetermined
                log("Microphone: unknown")
            }
        }
    }

    func requestMicrophonePermission() {
        log("requestMicrophonePermission called")
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                log("Microphone request result: \(granted ? "granted" : "denied")")
                Task { @MainActor in
                    self.microphoneStatus = granted ? .granted : .denied
                }
            }
        } else {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                log("Microphone request result: \(granted ? "granted" : "denied")")
                Task { @MainActor in
                    self.microphoneStatus = granted ? .granted : .denied
                }
            }
        }
    }

    func checkInputMonitoringPermission() {
        log("checkInputMonitoringPermission called")
        let accessType = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let canMonitor = accessType == kIOHIDAccessTypeGranted
        if canMonitor {
            inputMonitoringStatus = .granted
        } else if inputMonitoringRequested {
            inputMonitoringStatus = .requested
        } else {
            inputMonitoringStatus = .denied
        }
        log("InputMonitoring: \(inputMonitoringStatus) (accessType: \(accessType.rawValue))")
    }

    func requestInputMonitoringPermission() {
        log("requestInputMonitoringPermission called")
        UserDefaults.standard.set(true, forKey: "inputMonitoringRequested")

        let result = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        log("IOHIDRequestAccess result: \(result)")

        if result {
            inputMonitoringStatus = .granted
        } else {
            inputMonitoringStatus = .requested
            openSystemPreferences(for: "inputMonitoring")
        }
    }

    func checkAccessibilityPermission() {
        log("checkAccessibilityPermission called")
        let trusted = AXIsProcessTrustedWithOptions(nil)
        if trusted {
            accessibilityStatus = .granted
        } else if accessibilityRequested {
            accessibilityStatus = .requested
        } else {
            accessibilityStatus = .denied
        }
        log("Accessibility: \(accessibilityStatus)")
    }

    func checkFilesAndFoldersPermission() {
        log("checkFilesAndFoldersPermission called")
        // Try to access the WhisperKit cache directory to check if we have permission
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/WhisperKit")

        // Try to create/access the directory
        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            // Try to write a test file
            let testFile = cacheDir.appendingPathComponent(".permission_test")
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            filesAndFoldersStatus = .granted
            log("FilesAndFolders: granted")
        } catch {
            filesAndFoldersStatus = .denied
            log("FilesAndFolders: denied - \(error.localizedDescription)")
        }
    }

    func requestAccessibilityPermission() {
        log("requestAccessibilityPermission called")
        UserDefaults.standard.set(true, forKey: "accessibilityRequested")
        accessibilityStatus = .requested

        openSystemPreferences(for: "accessibility")
    }

    func openSystemPreferences(for permission: String) {
        log("openSystemPreferences called for: \(permission)")
        let urlString: String
        switch permission {
        case "microphone":
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case "inputMonitoring":
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        case "accessibility":
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case "filesAndFolders":
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
        default:
            log("openSystemPreferences: unknown permission \(permission)")
            return
        }

        log("openSystemPreferences: opening URL \(urlString)")
        if let url = URL(string: urlString) {
            let success = NSWorkspace.shared.open(url)
            log("openSystemPreferences: open result = \(success)")
        } else {
            log("openSystemPreferences: failed to create URL")
        }
    }
}
