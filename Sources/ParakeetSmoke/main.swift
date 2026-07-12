import FluidAudio
import Foundation

@main
struct ParakeetSmoke {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(
                Data("Usage: parakeet-smoke <audio-file>\n".utf8)
            )
            throw ExitCode.usage
        }

        let audioURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let samples = try AudioConverter().resampleAudioFile(audioURL)
        let manager = UnifiedAsrManager(encoderPrecision: .int8)

        FileHandle.standardError.write(Data("Loading model...\n".utf8))
        try await manager.loadModels()

        let started = ContinuousClock.now
        let transcript = try await manager.transcribe(samples)
        let elapsed = started.duration(to: .now)
        FileHandle.standardError.write(Data("Loading model: complete\n".utf8))
        print(transcript)
        FileHandle.standardError.write(Data("Transcription time: \(elapsed)\n".utf8))
    }
}

private enum ExitCode: Error {
    case usage
}
