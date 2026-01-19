import Foundation
import WhisperKit

enum TranscriptionError: Error, LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)
    case noAudioData
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model not loaded"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .noAudioData:
            return "No audio data to transcribe"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}

struct ModelInfo {
    let name: String
    let displayName: String
    let description: String
    let estimatedSize: String
    var isDownloaded: Bool
    var downloadedSize: String?
}

@MainActor
final class TranscriptionEngine: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isLoading = false
    @Published var isDownloading = false
    @Published var loadingProgress: Double = 0
    @Published var downloadProgress: Double = 0
    @Published var downloadingModel: String?
    @Published var modelInfos: [ModelInfo] = []

    @Published var selectedModel: String = "base" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }

    private var whisperKit: WhisperKit?

    static let availableModels = [
        "tiny",
        "base",
        "small",
        "medium",
        "large-v3"
    ]

    static let modelBasePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/WhisperKit/models/argmaxinc/whisperkit-coreml")

    init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedModel") {
            selectedModel = saved
        }
        refreshModelInfos()
    }

    func refreshModelInfos() {
        modelInfos = Self.availableModels.map { model in
            let isDownloaded = isModelDownloaded(model)
            let size = isDownloaded ? modelSize(model) : nil
            return ModelInfo(
                name: model,
                displayName: modelDisplayName(model),
                description: modelDescription(model),
                estimatedSize: estimatedModelSize(model),
                isDownloaded: isDownloaded,
                downloadedSize: size
            )
        }
    }

    func modelPath(_ model: String) -> URL {
        Self.modelBasePath.appendingPathComponent("openai_whisper-\(model)")
    }

    func isModelDownloaded(_ model: String) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(model).path)
    }

    func modelSize(_ model: String) -> String? {
        let path = modelPath(model)
        guard let size = try? FileManager.default.allocatedSizeOfDirectory(at: path) else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    func downloadModel(_ model: String) async throws {
        isDownloading = true
        downloadingModel = model
        downloadProgress = 0

        do {
            let _ = try await WhisperKit.download(
                variant: model,
                downloadBase: Self.modelBasePath.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(),
                from: "argmaxinc/whisperkit-coreml",
                progressCallback: { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }
            )
            refreshModelInfos()
        } catch {
            isDownloading = false
            downloadingModel = nil
            downloadProgress = 0
            throw TranscriptionError.downloadFailed(error.localizedDescription)
        }

        isDownloading = false
        downloadingModel = nil
        downloadProgress = 0
    }

    func deleteModel(_ model: String) throws {
        let path = modelPath(model)
        guard FileManager.default.fileExists(atPath: path.path) else { return }

        if selectedModel == model && isModelLoaded {
            whisperKit = nil
            isModelLoaded = false
        }

        try FileManager.default.removeItem(at: path)
        refreshModelInfos()
    }

    func loadModel() async throws {
        guard isModelDownloaded(selectedModel) else {
            throw TranscriptionError.modelNotLoaded
        }

        isLoading = true
        loadingProgress = 0

        let modelFolder = modelPath(selectedModel).path

        do {
            whisperKit = try await WhisperKit(
                modelFolder: modelFolder,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )
            isModelLoaded = true
            loadingProgress = 1.0
            isLoading = false
        } catch {
            isModelLoaded = false
            isLoading = false
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw TranscriptionError.modelNotLoaded
        }

        if audioSamples.isEmpty {
            throw TranscriptionError.noAudioData
        }

        let results = try await whisperKit.transcribe(audioArray: audioSamples)
        let text = results.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    func changeModel(to model: String) async throws {
        selectedModel = model
        isModelLoaded = false
        whisperKit = nil

        if isModelDownloaded(model) {
            try await loadModel()
        }
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

    private func modelDescription(_ model: String) -> String {
        switch model {
        case "tiny": return "Fastest • ~0.3s per 10s audio"
        case "base": return "Balanced • ~0.7s per 10s audio"
        case "small": return "Accurate • ~1.5s per 10s audio"
        case "medium": return "Very accurate • ~3s per 10s audio"
        case "large-v3": return "Best accuracy • ~6s per 10s audio"
        default: return ""
        }
    }

    private func estimatedModelSize(_ model: String) -> String {
        switch model {
        case "tiny": return "~75 MB"
        case "base": return "~145 MB"
        case "small": return "~480 MB"
        case "medium": return "~1.5 GB"
        case "large-v3": return "~3 GB"
        default: return "Unknown"
        }
    }
}

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> UInt64 {
        var size: UInt64 = 0
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]

        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: resourceKeys) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues.isDirectory == false {
                size += UInt64(resourceValues.fileSize ?? 0)
            }
        }

        return size
    }
}
