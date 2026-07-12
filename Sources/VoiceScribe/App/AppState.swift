import AppKit
import Combine
import Foundation
import VoiceScribeCore

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var state: RecordingState = .idle
    @Published var lastTranscription: String = ""
    @Published var audioLevel: Float = 0
    @Published var showOnboarding = false
    @Published var hasShownSettingsOnLaunch = false
    @Published var keyboardBinding: KeyboardBinding = .saved
    @Published var keyboardBindingEnabled = UserDefaults.standard.object(forKey: "keyboardBindingEnabled") == nil
        ? true : UserDefaults.standard.bool(forKey: "keyboardBindingEnabled")
    @Published var triggerMode: TriggerMode = .saved {
        didSet {
            _ = cancelRecording()
            triggerMode.save()
            restartMonitoring()
        }
    }
    @Published var mouseButtonNumber: Int64 = UserDefaults.standard.object(forKey: "mouseButtonNumber") == nil
        ? 3
        : Int64(UserDefaults.standard.integer(forKey: "mouseButtonNumber"))
    @Published var mouseBindingEnabled = UserDefaults.standard.object(forKey: "mouseBindingEnabled") == nil
        ? (UserDefaults.standard.object(forKey: "mouseButtonNumber") != nil)
        : UserDefaults.standard.bool(forKey: "mouseBindingEnabled")
    @Published var isCapturingKeyboardBinding = false
    @Published var isCapturingMouseButton = false

    let permissionManager = PermissionManager()
    let transcriptionEngine = TranscriptionEngine()

    private var keyMouseMonitor: KeyMouseMonitor?
    private var escapeKeyMonitor: EscapeKeyMonitor?
    private var mouseButtonCaptureMonitor: MouseButtonCaptureMonitor?
    private var keyboardBindingCaptureMonitor: KeyboardBindingCaptureMonitor?
    private var activeHoldSource: TriggerInputSource?
    private let audioRecorder = AudioRecorder()
    private let textInserter = TextInserter()

    private var audioLevelTimer: Timer?

    init() {
        setupMonitor()
    }

    func initialize() async {
        permissionManager.checkAllPermissions()

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if !hasCompletedOnboarding {
            showOnboarding = true
            return
        }

        if transcriptionEngine.isModelDownloaded(transcriptionEngine.selectedModel) {
            await loadModel()
        }

        startMonitoring()
    }

    func loadModel() async {
        guard transcriptionEngine.isModelDownloaded(transcriptionEngine.selectedModel) else {
            return
        }

        do {
            try await transcriptionEngine.loadModel()
            if permissionManager.microphoneStatus == .granted {
                audioRecorder.prepare()
            }
            state = .idle
        } catch {
            state = .error("Failed to load: \(error.localizedDescription)")
        }
    }

    func changeModel(to model: String) async {
        do {
            try await transcriptionEngine.changeModel(to: model)
            state = .idle
        } catch {
            state = .error("Could not switch model: \(error.localizedDescription)")
        }
    }

    func downloadModel(_ model: String) async {
        do {
            try await transcriptionEngine.downloadModel(model)
            state = .idle
        } catch {
            state = .error("Model download failed: \(error.localizedDescription)")
        }
    }

    var needsModelDownload: Bool {
        !transcriptionEngine.isModelDownloaded(transcriptionEngine.selectedModel)
    }

    func startMonitoring() {
        let escapeStarted = escapeKeyMonitor?.start() ?? false
        if !escapeStarted {
            state = .error("Failed to monitor Escape. Check Accessibility permission.")
        }

        guard let monitor = keyMouseMonitor else { return }
        if !monitor.start() {
            state = .error("Failed to start trigger monitoring. Check Accessibility permission.")
        }
    }

    func stopMonitoring() {
        keyMouseMonitor?.stop()
        escapeKeyMonitor?.stop()
    }

    private func restartMonitoring() {
        stopMonitoring()
        setupMonitor()
        // Only start if we're past onboarding and model is loaded
        if !showOnboarding && transcriptionEngine.isModelLoaded {
            startMonitoring()
        }
    }

    private func setupMonitor() {
        let callback: (TriggerInputSource, Bool) -> Void = { [weak self] source, pressed in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.handleTrigger(source: source, pressed: pressed)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleTrigger(source: source, pressed: pressed)
                }
            }
        }

        escapeKeyMonitor = EscapeKeyMonitor { [weak self] in
            self?.cancelRecording() ?? false
        }

        keyMouseMonitor = KeyMouseMonitor(
            keyboardBinding: keyboardBindingEnabled ? keyboardBinding : nil,
            mouseButtonNumber: mouseBindingEnabled ? mouseButtonNumber : nil,
            onStateChanged: callback
        )
    }

    private func handleTrigger(source: TriggerInputSource, pressed: Bool) {
        if triggerMode == .hold {
            if pressed && activeHoldSource == nil && state.isIdle {
                activeHoldSource = source
            } else if !pressed && activeHoldSource != source {
                return
            }
        }
        let phase: TriggerPhase
        if case .recording = state {
            phase = .recording
        } else if state.isIdle {
            phase = .idle
        } else {
            phase = .busy
        }

        let signal: TriggerSignal = pressed ? .pressed : .released
        switch TriggerInteraction.action(mode: triggerMode, signal: signal, phase: phase) {
        case .start:
            startRecording()
        case .transcribe:
            activeHoldSource = nil
            stopRecordingAndTranscribe()
        case nil:
            break
        }
    }

    @discardableResult
    func cancelRecording() -> Bool {
        guard case .recording = state else { return false }
        stopAudioLevelMonitoring()
        _ = audioRecorder.stopRecording()
        activeHoldSource = nil
        state = .idle
        NSSound(named: "Basso")?.play()
        return true
    }

    var triggerDisplayName: String {
        var names: [String] = []
        if keyboardBindingEnabled { names.append(keyboardBinding.displayName) }
        if mouseBindingEnabled { names.append("Mouse Button \(mouseButtonNumber + 1)") }
        return names.isEmpty ? "a configured trigger" : names.joined(separator: " or ")
    }

    var triggerInstruction: String {
        switch triggerMode {
        case .hold:
            return "Hold \(triggerDisplayName) to record"
        case .toggle:
            return "Press \(triggerDisplayName) to start or stop"
        }
    }

    func beginMouseButtonCapture() {
        guard !isCapturingMouseButton else { return }
        stopMonitoring()
        isCapturingMouseButton = true
        let monitor = MouseButtonCaptureMonitor { [weak self] buttonNumber in
            Task { @MainActor [weak self] in
                self?.completeMouseButtonCapture(buttonNumber: buttonNumber)
            }
        }
        mouseButtonCaptureMonitor = monitor
        if !monitor.start() {
            isCapturingMouseButton = false
            mouseButtonCaptureMonitor = nil
            restartMonitoring()
            state = .error("Failed to capture a mouse button. Check Accessibility permission.")
        }
    }

    func cancelMouseButtonCapture() {
        mouseButtonCaptureMonitor?.stop()
        mouseButtonCaptureMonitor = nil
        isCapturingMouseButton = false
        restartMonitoring()
    }

    private func completeMouseButtonCapture(buttonNumber: Int64) {
        mouseButtonCaptureMonitor?.stop()
        mouseButtonCaptureMonitor = nil
        isCapturingMouseButton = false
        mouseButtonNumber = buttonNumber
        UserDefaults.standard.set(buttonNumber, forKey: "mouseButtonNumber")
        setMouseBindingEnabled(true)
    }

    func beginKeyboardBindingCapture() {
        guard !isCapturingKeyboardBinding else { return }
        stopMonitoring()
        isCapturingKeyboardBinding = true
        let monitor = KeyboardBindingCaptureMonitor { [weak self] binding in
            Task { @MainActor [weak self] in self?.completeKeyboardBindingCapture(binding) }
        }
        keyboardBindingCaptureMonitor = monitor
        if !monitor.start() {
            isCapturingKeyboardBinding = false
            keyboardBindingCaptureMonitor = nil
            restartMonitoring()
            state = .error("Failed to capture a keyboard shortcut. Check Accessibility permission.")
        }
    }

    func cancelKeyboardBindingCapture() {
        keyboardBindingCaptureMonitor?.stop()
        keyboardBindingCaptureMonitor = nil
        isCapturingKeyboardBinding = false
        restartMonitoring()
    }

    private func completeKeyboardBindingCapture(_ binding: KeyboardBinding) {
        keyboardBindingCaptureMonitor?.stop()
        keyboardBindingCaptureMonitor = nil
        isCapturingKeyboardBinding = false
        keyboardBinding = binding
        binding.save()
        setKeyboardBindingEnabled(true)
    }

    func setKeyboardBindingEnabled(_ enabled: Bool) {
        keyboardBindingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "keyboardBindingEnabled")
        restartMonitoring()
    }

    func setMouseBindingEnabled(_ enabled: Bool) {
        mouseBindingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "mouseBindingEnabled")
        restartMonitoring()
    }

    private func startRecording() {
        guard state.isIdle else { return }
        guard transcriptionEngine.isModelLoaded else {
            state = .error("Model not loaded")
            return
        }

        do {
            try audioRecorder.startRecording()
            state = .recording
            startAudioLevelMonitoring()
            playStartSound()
        } catch {
            state = .error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func stopRecordingAndTranscribe() {
        guard case .recording = state else { return }

        stopAudioLevelMonitoring()
        let samples = audioRecorder.stopRecording()
        state = .processing

        Task {
            await transcribe(samples: samples)
        }
    }

    private func transcribe(samples: [Float]) async {
        do {
            let text = try await transcriptionEngine.transcribe(audioSamples: samples)

            if !text.isEmpty {
                lastTranscription = text
                textInserter.insertText(text)
                playSuccessSound()
            }

            state = .idle
        } catch {
            state = .error("Transcription failed: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.state = .idle
            }
        }
    }

    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.audioLevel = self?.audioRecorder.audioLevel ?? 0
            }
        }
    }

    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0
    }

    private func playStartSound() {
        NSSound(named: "Tink")?.play()
    }

    private func playSuccessSound() {
        NSSound(named: "Pop")?.play()
    }
}
