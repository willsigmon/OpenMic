# OpenMic - Voice AI for the Road

Voice-first AI assistant for iOS with CarPlay, Watch app, and 8 TTS engines.

## Tech Stack

- **Language**: Swift 6 (strict concurrency)
- **UI**: SwiftUI, iOS 18.6+, watchOS 10+
- **Data**: SwiftData (Conversation, Message, Persona models)
- **Audio**: SFSpeechRecognizer (STT) + Pipeline voice session (STT -> AI -> TTS)
- **Build**: XcodeGen (`xcodegen generate` to rebuild)
- **Packages**: SwiftOpenAI, SwiftAnthropic, KeychainAccess

## Architecture

### Voice Pipeline
```
SFSpeechSTT -> VoiceEndpointDetector -> AIProvider.streamChat() -> TTSEngine.speak()
     ^                                                                    |
     |_________________ PipelineVoiceSession (loop) _____________________|
```

### AI Providers (7)
| Provider | Type | Key |
|----------|------|-----|
| OpenAI | Cloud BYOK | `openmic.apikey.openai` |
| Anthropic | Cloud BYOK | `openmic.apikey.anthropic` |
| Gemini | Cloud BYOK | `openmic.apikey.gemini` |
| Grok | Cloud BYOK | `openmic.apikey.grok` |
| Ollama | Local | No key |
| Apple | Local (runtime-gated) | No key |
| OpenClaw | Self-hosted | Optional |

### TTS Engines (8)
System, OpenAI, ElevenLabs, Hume AI, Google Cloud, Cartesia, Amazon Polly, Deepgram

All cloud TTS engines use BYOK pattern with AVAudioPlayer playback and SystemTTS fallback.

## Key Files

| File | Purpose |
|------|---------|
| `App/AppServices.swift` | DI root: ModelContainer, KeychainManager, ConversationStore |
| `App/OpenMicApp.swift` | App entry, seeds default persona |
| `ViewModels/ConversationViewModel.swift` | Voice session lifecycle, bubble management, conversation persistence |
| `Services/Voice/PipelineVoiceSession.swift` | STT -> AI -> TTS pipeline loop |
| `Services/Voice/STT/SFSpeechSTT.swift` | On-device speech recognition |
| `Services/Providers/AIProviderFactory.swift` | Creates provider by type |
| `Services/Storage/KeychainManager.swift` | Actor-based keychain for all API keys |
| `Services/Storage/ConversationStore.swift` | SwiftData CRUD for conversations |
| `Models/Provider.swift` | AIProviderType enum with all metadata |
| `Models/VoiceConfig.swift` | TTSEngineType enum |
| `Models/Persona.swift` | SwiftData model with per-engine voice IDs |
| `DesignSystem/` | OpenMicTheme, GlassCard, AmbientBackground, haptics |

## Commands

```bash
xcodegen generate   # Rebuild Xcode project after adding files
```

## Development Notes

- Google Cloud TTS uses `X-Goog-Api-Key` header (NOT query string)
- Amazon Polly uses AWS SigV4 signing (implemented in AmazonPollyTTS)
- RealtimeVoiceSession routes managed OpenAI/Gemini realtime sessions via the proxy
- Apple Intelligence uses FoundationModels when available on supported runtimes
- CarPlay entitlement is currently commented out pending Apple Developer portal configuration
- Conversation history is seeded into PipelineVoiceSession on resume
- Topics tab navigates to Talk tab via `pendingPrompt` binding
- History tab resumes conversations via `pendingConversation` binding
