import CoreML
import Foundation
import WhisperKit

@main
struct WhisperBenchmark {
    static func main() async throws {
        guard CommandLine.arguments.count >= 3 else {
            print("usage: whisper-benchmark MODEL_FOLDER|download:VARIANT AUDIO_FILE [default|english|english-no-timestamps] [runs]")
            return
        }

        var modelFolder = CommandLine.arguments[1]
        if modelFolder.hasPrefix("download:") {
            let variant = String(modelFolder.dropFirst("download:".count))
            let base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/WhisperKit")
            let downloaded = try await WhisperKit.download(
                variant: variant,
                downloadBase: base,
                from: "argmaxinc/whisperkit-coreml"
            )
            modelFolder = downloaded.path
            print("downloaded_model=\(modelFolder)")
        }
        let audioPath = CommandLine.arguments[2]
        let mode = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "default"
        let runs = CommandLine.arguments.count > 4 ? Int(CommandLine.arguments[4]) ?? 3 : 3

        let options: DecodingOptions?
        switch mode {
        case "default":
            options = nil
        case "english":
            options = DecodingOptions(language: "en", detectLanguage: false)
        case "english-no-timestamps":
            options = DecodingOptions(
                language: "en",
                detectLanguage: false,
                withoutTimestamps: true
            )
        default:
            throw BenchmarkError.invalidMode(mode)
        }

        let loadStart = ContinuousClock.now
        let whisper = try await WhisperKit(
            modelFolder: modelFolder,
            computeOptions: ModelComputeOptions(),
            verbose: false,
            logLevel: .error,
            prewarm: false,
            load: true,
            download: false
        )
        print("load_seconds=\(seconds(since: loadStart))")

        for run in 1...runs {
            let start = ContinuousClock.now
            let results = try await whisper.transcribe(audioPath: audioPath, decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            print("run=\(run) seconds=\(seconds(since: start)) text=\(text)")
        }
    }

    private static func seconds(since start: ContinuousClock.Instant) -> String {
        let duration = start.duration(to: .now)
        let components = duration.components
        let value = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return String(format: "%.4f", value)
    }
}

enum BenchmarkError: LocalizedError {
    case invalidMode(String)

    var errorDescription: String? {
        switch self {
        case .invalidMode(let mode): return "Unknown benchmark mode: \(mode)"
        }
    }
}
