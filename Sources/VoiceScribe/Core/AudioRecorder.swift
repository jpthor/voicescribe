import AVFoundation
import Foundation

final class AudioRecorder {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    static let whisperSampleRate: Double = 16000

    var audioLevel: Float = 0

    func startRecording() throws {
        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.whisperSampleRate,
            channels: 1,
            interleaved: false
        )!

        let converter = AVAudioConverter(from: inputFormat, to: whisperFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            self.updateAudioLevel(buffer: buffer)

            if let converter = converter {
                let ratio = Self.whisperSampleRate / inputFormat.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: whisperFormat,
                    frameCapacity: outputFrameCapacity
                ) else { return }

                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                if error == nil, let channelData = convertedBuffer.floatChannelData {
                    let samples = Array(UnsafeBufferPointer(
                        start: channelData[0],
                        count: Int(convertedBuffer.frameLength)
                    ))
                    self.bufferLock.lock()
                    self.audioBuffer.append(contentsOf: samples)
                    self.bufferLock.unlock()
                }
            }
        }

        try audioEngine.start()
    }

    func stopRecording() -> [Float] {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        return samples
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataCount = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<channelDataCount {
            sum += abs(channelDataValue[i])
        }
        let average = sum / Float(channelDataCount)
        let level = 20 * log10(average + 1e-10)
        let normalizedLevel = max(0, min(1, (level + 50) / 50))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalizedLevel
        }
    }

    var isRecording: Bool {
        audioEngine.isRunning
    }
}
