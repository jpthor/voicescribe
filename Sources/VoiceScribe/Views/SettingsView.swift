import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var transcriptionEngine: TranscriptionEngine
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showResetConfirmation = false

    init(appState: AppState) {
        self.appState = appState
        self.transcriptionEngine = appState.transcriptionEngine
    }

    var body: some View {
        VStack(spacing: 16) {
            // App branding header
            HStack(spacing: 12) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("VoiceScribe")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Local speech recognition powered by WhisperKit. All processing on-device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismissWindow(id: "settings")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.bottom, 4)

            Divider()

            // Models section
            modelSection

            Divider()

            // Permissions section
            permissionsSection

            Divider()

            // Fn key usage
            fnKeySection

            Spacer()
        }
        .padding()
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(width: 450, height: 680)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.permissionManager.checkAllPermissions()
        }
        .alert("Delete Model?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    try? transcriptionEngine.deleteModel(model)
                }
            }
        } message: {
            if let model = modelToDelete {
                Text("This will delete the \(model) model and free up disk space.")
            }
        }
        .alert("Reset & Restart Onboarding?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset & Quit", role: .destructive) {
                resetAndRestartOnboarding()
            }
        } message: {
            Text("This will reset app settings and quit. You'll need to re-grant permissions in System Settings before relaunching.")
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Whisper Models")
                    .font(.headline)
                Spacer()
                if transcriptionEngine.isDownloading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Downloading \(transcriptionEngine.downloadingModel ?? "")...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(transcriptionEngine.modelInfos, id: \.name) { info in
                        ModelRowView(
                            info: info,
                            isSelected: transcriptionEngine.selectedModel == info.name,
                            isDownloading: transcriptionEngine.downloadingModel == info.name,
                            isAnyDownloading: transcriptionEngine.isDownloading,
                            downloadProgress: transcriptionEngine.downloadProgress,
                            onSelect: {
                                Task {
                                    try? await transcriptionEngine.changeModel(to: info.name)
                                }
                            },
                            onDownload: {
                                Task {
                                    try? await transcriptionEngine.downloadModel(info.name)
                                }
                            },
                            onDelete: {
                                modelToDelete = info.name
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
            .frame(height: 260)

            if transcriptionEngine.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading model...")
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.headline)

            PermissionRowView(
                title: "Microphone",
                status: appState.permissionManager.microphoneStatus,
                action: { appState.permissionManager.openSystemPreferences(for: "microphone") }
            )

            PermissionRowView(
                title: "Input Monitoring",
                status: appState.permissionManager.inputMonitoringStatus,
                action: { appState.permissionManager.openSystemPreferences(for: "inputMonitoring") }
            )

            PermissionRowView(
                title: "Accessibility",
                status: appState.permissionManager.accessibilityStatus,
                action: { appState.permissionManager.openSystemPreferences(for: "accessibility") }
            )

            PermissionRowView(
                title: "Files & Folders",
                status: appState.permissionManager.filesAndFoldersStatus,
                action: { appState.permissionManager.openSystemPreferences(for: "filesAndFolders") }
            )

            LaunchAtLoginRowView(isEnabled: $launchAtLogin)

            HStack {
                Text("If any permission isn't working: remove it in System Settings, re-add, then restart.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Reset All") {
                    showResetConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func resetAndRestartOnboarding() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.voicescribe.app"

        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "inputMonitoringRequested")

        let permissions = ["Microphone", "Accessibility", "ListenEvent", "SystemPolicyDocumentsFolder"]
        for permission in permissions {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", permission, bundleId]
            try? process.run()
            process.waitUntilExit()
        }

        NSApplication.shared.terminate(nil)
    }

    @ViewBuilder
    private var fnKeySection: some View {
        HStack(spacing: 16) {
            Text("fn")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Hold Fn key to record")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Release to transcribe into any app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct ModelRowView: View {
    let info: ModelInfo
    let isSelected: Bool
    let isDownloading: Bool
    let isAnyDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(info.displayName)
                        .fontWeight(isSelected ? .semibold : .regular)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                HStack(spacing: 8) {
                    Text(info.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(info.isDownloaded ? (info.downloadedSize ?? info.estimatedSize) : info.estimatedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isDownloading {
                HStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .frame(width: 80)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 35, alignment: .trailing)
                }
            } else if info.isDownloaded {
                HStack(spacing: 6) {
                    if !isSelected {
                        Button("Use") {
                            onSelect()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .disabled(isAnyDownloading)
                }
            } else {
                Button("Download") {
                    onDownload()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isAnyDownloading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : (isDownloading ? Color.blue.opacity(0.05) : Color.clear))
        .cornerRadius(6)
    }
}

struct PermissionRowView: View {
    let title: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: status == .granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(status == .granted ? .green : .red)
                Text(status == .granted ? "Granted" : "Denied")
                    .font(.caption)
            }
            if status != .granted {
                Button("Fix") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct LaunchAtLoginRowView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            Text("Launch at Login")
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isEnabled ? .green : .red)
                Text(isEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
            }
            Button(isEnabled ? "Disable" : "Enable") {
                do {
                    if isEnabled {
                        try SMAppService.mainApp.unregister()
                        isEnabled = false
                    } else {
                        try SMAppService.mainApp.register()
                        isEnabled = true
                    }
                } catch {
                    // Failed to change state
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
