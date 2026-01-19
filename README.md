# VoiceScribe

A macOS menu bar app that provides local speech-to-text transcription using OpenAI's Whisper model. All processing happens on-device via WhisperKit - no cloud services required.

## Features

- **Push-to-talk**: Hold Fn key to record, release to transcribe
- **Auto-insert**: Transcribed text is automatically typed into the active application
- **Privacy-focused**: 100% local processing, no data leaves your Mac
- **Multiple Whisper models**: Choose between speed and accuracy
- **Menu bar interface**: Always accessible, minimal footprint
- **Audio feedback**: Sound cues for recording start and transcription complete

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3)
- ~150 MB disk space for the Base model (more for larger models)

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
- Install to `/Applications`

3. Launch from `/Applications/VoiceScribe.app`

**Note**: You'll need to update the code signing identity in `build-app.sh` to match your own Apple Developer certificate, or remove the signing step for local testing.

## Usage

1. **First launch**: Grant the required permissions when prompted
2. **Download a model**: Open Settings from the menu bar icon and download a Whisper model
3. **Start transcribing**: Hold the **Fn key** while speaking, release when done
4. The transcribed text will be automatically inserted at your cursor position

### Workflow

```
Hold Fn → Speak → Release Fn → Text appears
```

## Whisper Models

| Model | Size | Description |
|-------|------|-------------|
| Tiny | ~75 MB | Fastest, basic accuracy |
| Base | ~145 MB | Good balance (recommended) |
| Small | ~480 MB | Better accuracy |
| Medium | ~1.5 GB | High accuracy |
| Large v3 | ~3 GB | Best accuracy |

Models are downloaded on-demand and cached locally. You can download multiple models and switch between them in Settings.

## Permissions

VoiceScribe requires three system permissions:

| Permission | Purpose |
|------------|---------|
| **Microphone** | Record audio for transcription |
| **Input Monitoring** | Detect Fn key press/release |
| **Accessibility** | Insert transcribed text into apps |

On first launch, an onboarding screen will guide you through granting these permissions. You can also manage them in Settings or System Settings > Privacy & Security.

## Technology

- **Swift** / **SwiftUI**
- **WhisperKit** - OpenAI Whisper models optimized for Apple Silicon
- **AVFoundation** - Audio recording
- **IOKit** - Fn key monitoring
- **Accessibility API** - Text insertion

## License

MIT
