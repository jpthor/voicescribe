# VoiceScribe

A macOS menu bar app that provides local speech-to-text transcription. Apple Silicon Macs default to Parakeet Unified English through FluidAudio, with WhisperKit models available as fallbacks. No audio is sent to a cloud service.

## Features

- **Independent triggers**: Learn any keyboard shortcut and an auxiliary mouse button; keep either or both enabled
- **Hold or toggle**: Hold a trigger, or press once to start and again to transcribe
- **Cancel safely**: Press Escape during recording to discard it without transcription
- **Auto-insert**: Transcribed text is automatically typed into the active application
- **Privacy-focused**: 100% local processing, no data leaves your Mac
- **Fast English dictation**: Parakeet Unified English uses an INT8 Core ML encoder
- **Whisper fallbacks**: Choose a Whisper model when you need a second engine
- **Menu bar interface**: Always accessible, minimal footprint
- **Audio feedback**: Sound cues for recording start and transcription complete

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1 or later) for Parakeet Unified English
- ~600 MB disk space for the recommended model

## Installation

### Build from Source

1. Clone the repository
2. Run the build script:

```bash
./build-app.sh
```

This will:
- Build the app in release mode
- Create the app bundle
- Code sign the app

3. Launch from `/Applications/VoiceScribe.app`

**Note**: You'll need to update the code signing identity in `build-app.sh` to match your own Apple Developer certificate, or remove the signing step for local testing.

## Usage

1. **First launch**: Grant the required permissions when prompted
2. **Download a model**: The onboarding flow downloads Parakeet Unified English by default
3. **Bind triggers**: Learn a keyboard shortcut and/or an auxiliary mouse button in Settings
4. **Choose Hold or Toggle**: Release a held trigger, or press a toggle trigger again, to transcribe
5. Press **Escape** while recording to cancel and discard the audio
6. The transcribed text will be automatically inserted at your cursor position

### Workflow

```
Trigger → Speak → Finish trigger → Text appears
```

## Speech Models

| Model | Size | Speed (10s audio) | Description |
|-------|------|-------------------|-------------|
| Parakeet Unified English | ~600 MB | Effectively immediate | Recommended for accurate English dictation with punctuation and capitalisation |
| Tiny | ~75 MB | ~0.1s | Fastest, basic accuracy |
| Base | ~145 MB | ~0.1s | Good balance (recommended) |
| Small | ~480 MB | ~0.2s | Better accuracy |
| Medium | ~1.5 GB | ~0.6s | High accuracy |
| Large v3 | ~3 GB | ~1.1s | Best accuracy |

*Speeds measured on Apple Silicon. All models transcribe faster than real-time.*

Models are downloaded on-demand and cached locally. You can download multiple models and switch between them in Settings.

## Permissions

VoiceScribe requires the following system permissions:

| Permission | Purpose | Required |
|------------|---------|----------|
| **Files & Folders** | Store downloaded Whisper models in Documents | Yes |
| **Microphone** | Capture audio for transcription | Yes |
| **Accessibility** | Insert transcribed text into apps | Yes |
| **Input Monitoring** | Detect Fn key press/release | Yes |

Optional:

| Setting | Purpose |
|---------|---------|
| **Launch at Login** | Start VoiceScribe automatically when you log in |

On first launch, an onboarding screen will guide you through granting these permissions. You can also manage them in Settings or System Settings > Privacy & Security.

**Note**: Granting Input Monitoring permission will restart the app automatically.

## Technology

- **Swift** / **SwiftUI**
- **FluidAudio** - Parakeet Unified English optimized for Apple Silicon
- **WhisperKit** - OpenAI Whisper fallback models optimized for Apple Silicon
- **AVFoundation** - Audio recording
- **IOKit** - Fn key monitoring
- **Accessibility API** - Text insertion

## License

MIT
