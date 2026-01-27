import Foundation
import VoiceScribeCore

#if arch(arm64)
import WhisperKit
import CoreML
#else
import SwiftWhisper
#endif

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

    @Published var selectedModel: String = "tiny" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }

    #if arch(arm64)
    private var whisperKit: WhisperKit?
    static let availableModels = ModelMetadata.availableModels
    static let modelBasePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/WhisperKit/models/argmaxinc/whisperkit-coreml")
    #else
    private var whisper: Whisper?
    static let availableModels = ["tiny", "base", "small", "medium"]
    static let modelBasePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/VoiceScribe/whisper-ggml")

    private static let modelURLs: [String: String] = [
        "tiny": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
        "base": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
        "small": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
        "medium": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin"
    ]
    #endif

    init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedModel"),
           Self.availableModels.contains(saved) {
            selectedModel = saved
        } else {
            selectedModel = "tiny"
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
        #if arch(arm64)
        return Self.modelBasePath.appendingPathComponent("openai_whisper-\(model)")
        #else
        return Self.modelBasePath.appendingPathComponent("ggml-\(model).bin")
        #endif
    }

    func isModelDownloaded(_ model: String) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(model).path)
    }

    func modelSize(_ model: String) -> String? {
        let path = modelPath(model)
        #if arch(arm64)
        guard let size = try? FileManager.default.allocatedSizeOfDirectory(at: path) else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        #else
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? UInt64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        #endif
    }

    func downloadModel(_ model: String) async throws {
        isDownloading = true
        downloadingModel = model
        downloadProgress = 0

        #if arch(arm64)
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
        #else
        guard let urlString = Self.modelURLs[model],
              let url = URL(string: urlString) else {
            isDownloading = false
            downloadingModel = nil
            throw TranscriptionError.downloadFailed("Unknown model: \(model)")
        }

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: Self.modelBasePath, withIntermediateDirectories: true)

        let destination = modelPath(model)

        do {
            let (tempURL, _) = try await downloadFile(from: url) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                }
            }

            // Move to final destination
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            refreshModelInfos()
        } catch {
            isDownloading = false
            downloadingModel = nil
            downloadProgress = 0
            throw TranscriptionError.downloadFailed(error.localizedDescription)
        }
        #endif

        isDownloading = false
        downloadingModel = nil
        downloadProgress = 0
    }

    func deleteModel(_ model: String) throws {
        let path = modelPath(model)
        guard FileManager.default.fileExists(atPath: path.path) else { return }

        if selectedModel == model && isModelLoaded {
            #if arch(arm64)
            whisperKit = nil
            #else
            whisper = nil
            #endif
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

        #if arch(arm64)
        let modelFolder = modelPath(selectedModel).path
        let computeOptions = ModelComputeOptions()

        do {
            whisperKit = try await WhisperKit(
                modelFolder: modelFolder,
                computeOptions: computeOptions,
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
        #else
        let modelURL = modelPath(selectedModel)

        let loadedWhisper = await Task.detached(priority: .userInitiated) {
            return Whisper(fromFileURL: modelURL, withParams: .default)
        }.value

        whisper = loadedWhisper
        isModelLoaded = true
        loadingProgress = 1.0
        isLoading = false
        #endif
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        #if arch(arm64)
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw TranscriptionError.modelNotLoaded
        }

        if audioSamples.isEmpty {
            throw TranscriptionError.noAudioData
        }

        let results = try await whisperKit.transcribe(audioArray: audioSamples)
        let text = results.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text
        #else
        guard let whisper = whisper, isModelLoaded else {
            throw TranscriptionError.modelNotLoaded
        }

        if audioSamples.isEmpty {
            throw TranscriptionError.noAudioData
        }

        let segments = try await whisper.transcribe(audioFrames: audioSamples)
        let text = segments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text
        #endif
    }

    func changeModel(to model: String) async throws {
        selectedModel = model
        isModelLoaded = false
        #if arch(arm64)
        whisperKit = nil
        #else
        whisper = nil
        #endif

        if isModelDownloaded(model) {
            try await loadModel()
        }
    }

    private func modelDisplayName(_ model: String) -> String {
        ModelMetadata.displayName(for: model)
    }

    private func modelDescription(_ model: String) -> String {
        ModelMetadata.description(for: model)
    }

    private func estimatedModelSize(_ model: String) -> String {
        ModelMetadata.estimatedSize(for: model)
    }

    #if arch(x86_64)
    // Helper for downloading files with progress on Intel
    private func downloadFile(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL = tempURL, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                // Copy to a location that won't be deleted
                let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.copyItem(at: tempURL, to: destURL)
                    continuation.resume(returning: (destURL, response))
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Observe progress
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                progressHandler(progress.fractionCompleted)
            }

            task.resume()

            // Clean up observation when task completes
            DispatchQueue.global().async {
                while task.state == .running {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                observation.invalidate()
            }
        }
    }
    #endif
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
