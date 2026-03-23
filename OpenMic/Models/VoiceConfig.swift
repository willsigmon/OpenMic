import Foundation

struct VoiceConfig: Codable, Sendable {
    var ttsEngine: TTSEngineType
    var sttEnabled: Bool
    var vadSilenceThreshold: Double
    var vadSilenceDuration: Double

    static let `default` = VoiceConfig(
        ttsEngine: .system,
        sttEnabled: true,
        vadSilenceThreshold: -40.0,
        vadSilenceDuration: 1.5
    )
}

enum TTSEngineType: String, Codable, Sendable, CaseIterable, Identifiable {
    case system
    case localNeural
    case openAI
    case elevenLabs
    case humeAI
    case googleCloud
    case cartesia
    case amazonPolly
    case deepgram

    var id: String { rawValue }

    /// Keychain storage key for this TTS engine's API credentials
    var keychainKey: String {
        switch self {
        case .system: "openmic.tts.system"
        case .localNeural: "openmic.tts.localneural"
        case .openAI: "openmic.apikey.openai"
        case .elevenLabs: "openmic.apikey.elevenlabs"
        case .humeAI: "openmic.apikey.humeai"
        case .googleCloud: "openmic.apikey.googlecloud"
        case .cartesia: "openmic.apikey.cartesia"
        case .amazonPolly: "openmic.apikey.polly.access"
        case .deepgram: "openmic.apikey.deepgram"
        }
    }

    /// Amazon Polly uses a second key (secret key) alongside the access key
    var secondaryKeychainKey: String? {
        switch self {
        case .amazonPolly: "openmic.apikey.polly.secret"
        default: nil
        }
    }

    var displayName: String {
        switch self {
        case .system: "System (Neural)"
        case .localNeural: "Kokoro (On-Device)"
        case .openAI: "OpenAI"
        case .elevenLabs: "ElevenLabs"
        case .humeAI: "Hume AI (Expressive)"
        case .googleCloud: "Google Cloud TTS"
        case .cartesia: "Cartesia (Ultra-Fast)"
        case .amazonPolly: "Amazon Polly"
        case .deepgram: "Deepgram Aura"
        }
    }

    /// Whether this engine requires a network connection
    var isOfflineCapable: Bool {
        switch self {
        case .system, .localNeural: true
        default: false
        }
    }
}
