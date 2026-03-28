import Foundation

/// Single source of truth for constructing a `TTSEngineProtocol` from the
/// user's selected engine type, keychain credentials, and optional persona
/// voice overrides.
///
/// Both `ConversationViewModel` and `CarPlayVoiceController` delegate to this
/// builder so the construction logic lives in exactly one place.
@MainActor
enum TTSEngineBuilder {

    /// Build the TTS engine for the currently-selected engine type.
    ///
    /// - Parameters:
    ///   - engine: Which TTS backend to construct.
    ///   - keychainManager: Actor-based keychain used to retrieve API keys.
    ///   - persona: Optional active persona whose per-engine voice IDs are
    ///     applied when present.
    /// - Returns: A fully-configured engine, or a `SystemTTS` fallback when
    ///   required credentials are missing.
    static func build(
        engine: TTSEngineType,
        keychainManager: KeychainManager,
        persona: Persona? = nil
    ) async -> TTSEngineProtocol {
        switch engine {
        case .system:
            let tts = SystemTTS()
            if let voiceId = persona?.systemTTSVoice {
                tts.setVoice(identifier: voiceId)
            }
            return tts

        case .localNeural:
            return LocalNeuralTTS()

        case .openAI:
            guard let key = try? await keychainManager.getAPIKey(for: .openAI),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let modelRaw = UserDefaults.standard.string(forKey: "openAITTSModel")
                ?? OpenAITTSModel.tts1.rawValue
            let model = OpenAITTSModel(rawValue: modelRaw) ?? .tts1

            let tts = OpenAITTS(apiKey: key, model: model)
            if let voice = persona?.openAITTSVoice {
                tts.setVoice(voice)
            }
            return tts

        case .elevenLabs:
            guard let key = try? await keychainManager.getTTSKey(for: .elevenLabs),
                  !key.isEmpty else {
                let tts = SystemTTS()
                if let voiceId = persona?.systemTTSVoice {
                    tts.setVoice(identifier: voiceId)
                }
                return tts
            }

            let modelRaw = UserDefaults.standard.string(forKey: "elevenLabsModel")
                ?? ElevenLabsModel.flash.rawValue
            let model = ElevenLabsModel(rawValue: modelRaw) ?? .flash

            let tts = ElevenLabsTTS(apiKey: key, model: model)
            if let voiceId = persona?.elevenLabsVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .humeAI:
            guard let key = try? await keychainManager.getTTSKey(for: .humeAI),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let tts = HumeAITTS(apiKey: key)
            if let voiceId = persona?.humeAIVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .googleCloud:
            guard let key = try? await keychainManager.getTTSKey(for: .googleCloud),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let tts = GoogleCloudTTS(apiKey: key)
            if let voiceId = persona?.googleCloudVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .cartesia:
            guard let key = try? await keychainManager.getTTSKey(for: .cartesia),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let tts = CartesiaTTS(apiKey: key)
            if let voiceId = persona?.cartesiaVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .amazonPolly:
            guard let accessKey = try? await keychainManager.getTTSKey(for: .amazonPolly),
                  let secretKey = try? await keychainManager.getTTSSecondaryKey(for: .amazonPolly),
                  !accessKey.isEmpty, !secretKey.isEmpty else {
                return SystemTTS()
            }

            let tts = AmazonPollyTTS(accessKey: accessKey, secretKey: secretKey)
            if let voiceId = persona?.amazonPollyVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .deepgram:
            guard let key = try? await keychainManager.getTTSKey(for: .deepgram),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let tts = DeepgramTTS(apiKey: key)
            if let voiceId = persona?.deepgramVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts
        }
    }
}
