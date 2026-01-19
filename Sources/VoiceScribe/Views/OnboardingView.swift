import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var transcriptionEngine: TranscriptionEngine
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var hasStartedTinyDownload = false
    @State private var downloadFailed = false

    init(appState: AppState) {
        self.appState = appState
        self.transcriptionEngine = appState.transcriptionEngine
    }

    private let permissionSteps = [
        OnboardingStep(
            icon: "folder.fill",
            title: "Files & Folders",
            description: "Required to download and store Whisper speech recognition models locally on your Mac. Allow access when prompted.",
            permissionKey: "storage"
        ),
        OnboardingStep(
            icon: "mic.fill",
            title: "Microphone Access",
            description: "Required to capture your voice when you hold the Fn key. Audio is processed entirely on-device and never sent anywhere.",
            permissionKey: "microphone"
        ),
        OnboardingStep(
            icon: "keyboard",
            title: "Input Monitoring",
            description: "Required to detect when you press and release the Fn key to start/stop recording. Click + in System Settings, select VoiceScribe from Applications, and toggle it on.",
            permissionKey: "inputMonitoring"
        ),
        OnboardingStep(
            icon: "accessibility",
            title: "Accessibility",
            description: "Required to automatically type the transcribed text into whatever app you're using. Without this, text cannot be inserted.",
            permissionKey: "accessibility"
        )
    ]

    private let totalSteps = 6 // 1 welcome + 4 permissions + 1 model download

    var body: some View {
        VStack(spacing: 24) {
            headerSection

            Divider()

            if currentStep == 0 {
                welcomeContent
            } else if currentStep <= permissionSteps.count {
                permissionStepContent
            } else {
                modelDownloadContent
            }

            Spacer()

            navigationButtons
        }
        .padding(24)
        .frame(width: 450, height: 580)
        .onAppear {
            appState.permissionManager.checkAllPermissions()
            startTinyDownloadIfNeeded()
        }
    }

    private func startTinyDownloadIfNeeded() {
        guard !hasStartedTinyDownload else { return }
        guard !appState.transcriptionEngine.isModelDownloaded("tiny") else { return }

        hasStartedTinyDownload = true
        Task {
            do {
                try await appState.transcriptionEngine.downloadModel("tiny")
            } catch {
                await MainActor.run {
                    downloadFailed = true
                }
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Welcome to VoiceScribe")
                .font(.title)
                .fontWeight(.bold)

            if currentStep > 0 {
                Text("Let's set up the permissions needed for voice transcription")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var welcomeContent: some View {
        VStack(spacing: 16) {
            stepIndicator

            Text("Local speech-to-text transcription powered by WhisperKit. All processing happens on-device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Fn key usage instruction
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Text("fn")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hold Fn key to record")
                            .font(.headline)
                        Text("Release to transcribe into any app")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Setup steps:")
                    .font(.headline)
                    .padding(.bottom, 4)

                stepsOverviewRow(number: 1, text: "Files & Folders", icon: "folder.fill")
                stepsOverviewRow(number: 2, text: "Microphone", icon: "mic.fill")
                stepsOverviewRow(number: 3, text: "Input Monitoring", icon: "keyboard")
                stepsOverviewRow(number: 4, text: "Accessibility", icon: "accessibility")
                stepsOverviewRow(number: 5, text: "Download Model", icon: "arrow.down.circle.fill")
            }
        }
    }

    @ViewBuilder
    private func stepsOverviewRow(number: Int, text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Text("\(number).")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private var permissionStepContent: some View {
        let step = permissionSteps[currentStep - 1]
        let status = permissionStatus(for: step.permissionKey)

        VStack(spacing: 16) {
            stepIndicator

            Image(systemName: step.icon)
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
                .frame(height: 50)

            Text(step.title)
                .font(.headline)

            Text(step.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if step.permissionKey == "storage" {
                // No button needed - just use bottom Next button
            } else if step.permissionKey == "inputMonitoring" {
                if status == .granted {
                    statusView(for: status)
                } else {
                    VStack(spacing: 12) {
                        Button(action: {
                            UserDefaults.standard.set(true, forKey: "inputMonitoringRequested")
                            appState.permissionManager.openSystemPreferences(for: "inputMonitoring")
                        }) {
                            Label("Open System Settings", systemImage: "gear")
                        }
                        .buttonStyle(.borderedProminent)

                        Text("After adding VoiceScribe, System Settings will restart the app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                statusView(for: status)

                if status != .granted && status != .requested {
                    Button(action: { grantPermission(for: step.permissionKey) }) {
                        Label("Grant Permission", systemImage: "lock.open")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ViewBuilder
    private var modelDownloadContent: some View {
        VStack(spacing: 16) {
            stepIndicator

            Image(systemName: downloadFailed ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(downloadFailed ? .orange : .accentColor)
                .frame(height: 50)

            Text(downloadFailed ? "Documents Access Required" : "Download Model")
                .font(.headline)

            if downloadFailed {
                Text("VoiceScribe needs Documents folder access to download models. Please enable it in System Settings, then tap Retry.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("Open System Settings", systemImage: "gear")
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        downloadFailed = false
                        hasStartedTinyDownload = false
                        startTinyDownloadIfNeeded()
                    }) {
                        Label("Retry Download", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Downloading the Tiny model for quick start. You can download larger models for better accuracy in Settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Tiny model status
                VStack(spacing: 12) {
                    if appState.transcriptionEngine.downloadingModel == "tiny" {
                        ProgressView(value: appState.transcriptionEngine.downloadProgress)
                            .frame(width: 200)
                        Text("Downloading... \(Int(appState.transcriptionEngine.downloadProgress * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    } else if appState.transcriptionEngine.modelInfos.first(where: { $0.name == "tiny" })?.isDownloaded == true {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready to go!")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .font(.title3)
                    } else {
                        ProgressView()
                        Text("Preparing download...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var stepIndicator: some View {
        HStack {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    @ViewBuilder
    private func statusView(for status: PermissionStatus) -> some View {
        HStack(spacing: 6) {
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Permission Granted")
                    .foregroundColor(.green)
            case .requested:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Permission Requested")
                    .foregroundColor(.blue)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
                Text("Permission Required")
                    .foregroundColor(.orange)
            case .notDetermined:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
                Text("Permission Required")
                    .foregroundColor(.orange)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button(currentStep == 0 ? "Get Started" : "Next") {
                    withAnimation {
                        currentStep += 1
                    }
                    appState.permissionManager.checkAllPermissions()
                }
                .buttonStyle(.borderedProminent)
            } else {
                // Final step
                Button("Quit and Restart") {
                    Task {
                        await finishOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canFinish)
            }
        }
    }

    private var canFinish: Bool {
        appState.transcriptionEngine.isModelDownloaded("tiny")
    }

    private func finishOnboarding() async {
        let engine = appState.transcriptionEngine

        // Wait for tiny to finish if still downloading
        while engine.downloadingModel == "tiny" {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Set tiny as the selected model
        engine.selectedModel = "tiny"

        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        relaunchApp()
    }

    private func relaunchApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        NSApplication.shared.terminate(nil)
    }

    private func permissionStatus(for key: String) -> PermissionStatus {
        switch key {
        case "microphone":
            return appState.permissionManager.microphoneStatus
        case "inputMonitoring":
            return appState.permissionManager.inputMonitoringStatus
        case "accessibility":
            return appState.permissionManager.accessibilityStatus
        default:
            return .notDetermined
        }
    }

    private func grantPermission(for key: String) {
        switch key {
        case "microphone":
            appState.permissionManager.requestMicrophonePermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                appState.permissionManager.checkAllPermissions()
            }
        case "accessibility":
            appState.permissionManager.requestAccessibilityPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    currentStep += 1
                }
            }
        default:
            break
        }
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    let permissionKey: String
}
