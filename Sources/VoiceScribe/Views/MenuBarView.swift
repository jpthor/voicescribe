import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var showCopiedFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusSection
            Divider()
            modelSection
            Divider()
            lastTranscriptionSection
            Divider()
            controlsSection
        }
        .padding()
        .frame(width: 300)
        .onChange(of: appState.showOnboarding) { showOnboarding in
            if showOnboarding {
                openWindow(id: "onboarding")
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        HStack {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.headline)
                Text(statusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if case .recording = appState.state {
                AudioLevelIndicator(level: appState.audioLevel)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if appState.transcriptionEngine.isDownloading || appState.transcriptionEngine.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if appState.needsModelDownload || !appState.transcriptionEngine.isModelLoaded {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
            } else {
                switch appState.state {
                case .idle:
                    Image(systemName: "mic.fill")
                        .foregroundColor(.green)
                case .recording:
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                case .processing:
                    ProgressView()
                        .controlSize(.small)
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
        }
        .frame(width: 24, height: 24)
    }

    private var statusText: String {
        if appState.transcriptionEngine.isDownloading {
            return "Downloading..."
        }
        if appState.transcriptionEngine.isLoading {
            return "Loading Model..."
        }
        if appState.needsModelDownload {
            return "Setup Required"
        }
        if !appState.transcriptionEngine.isModelLoaded {
            return "No Model"
        }
        switch appState.state {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .error:
            return "Error"
        }
    }

    private var statusDescription: String {
        if appState.transcriptionEngine.isDownloading {
            let model = appState.transcriptionEngine.downloadingModel ?? "model"
            let progress = Int(appState.transcriptionEngine.downloadProgress * 100)
            return "Downloading \(model)... \(progress)%"
        }
        if appState.transcriptionEngine.isLoading {
            return "Please wait..."
        }
        if appState.needsModelDownload {
            return "Open Settings to download a model"
        }
        if !appState.transcriptionEngine.isModelLoaded {
            return "Select a model in Settings"
        }
        switch appState.state {
        case .idle:
            return "Hold Fn key to record"
        case .recording:
            return "Release Fn to stop"
        case .processing:
            return "Transcribing audio..."
        case .error(let message):
            return message
        }
    }

    @ViewBuilder
    private var lastTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Last Transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !appState.lastTranscription.isEmpty {
                    Button(action: copyTranscription) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(showCopiedFeedback ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy to clipboard")
                }
            }

            if appState.lastTranscription.isEmpty {
                Text("No transcriptions yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(appState.lastTranscription)
                    .font(.body)
                    .lineLimit(3)
            }
        }
    }

    private func copyTranscription() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.lastTranscription, forType: .string)

        withAnimation {
            showCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        HStack {
            Text("Model")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if appState.transcriptionEngine.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Picker("", selection: Binding(
                    get: { appState.transcriptionEngine.selectedModel },
                    set: { newModel in
                        Task {
                            try? await appState.transcriptionEngine.changeModel(to: newModel)
                            if appState.transcriptionEngine.isModelLoaded {
                                appState.state = .idle
                            }
                        }
                    }
                )) {
                    ForEach(downloadedModels, id: \.self) { model in
                        Text(modelDisplayName(model)).tag(model)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }
        }
    }

    private var downloadedModels: [String] {
        appState.transcriptionEngine.modelInfos
            .filter { $0.isDownloaded }
            .map { $0.name }
    }

    private func modelDisplayName(_ model: String) -> String {
        switch model {
        case "tiny": return "Tiny"
        case "base": return "Base"
        case "small": return "Small"
        case "medium": return "Medium"
        case "large-v3": return "Large v3"
        default: return model.capitalized
        }
    }

    @ViewBuilder
    private var controlsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Settings...") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

struct AudioLevelIndicator: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
        .frame(width: 40, height: 8)
    }

    private var levelColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
}
