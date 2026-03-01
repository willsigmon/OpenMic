import Foundation

// MARK: - Deepgram Aura Voice

struct DeepgramVoice: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String

    var displayName: String { name }
}

// MARK: - Built-in Voice Catalog

enum DeepgramVoiceCatalog {
    static let aura2Voices: [DeepgramVoice] = [
        DeepgramVoice(id: "aura-2-theia-en", name: "Theia", description: "Warm and professional female voice"),
        DeepgramVoice(id: "aura-2-andromeda-en", name: "Andromeda", description: "Expressive and engaging female voice"),
        DeepgramVoice(id: "aura-2-luna-en", name: "Luna", description: "Soft and calm female voice"),
        DeepgramVoice(id: "aura-2-athena-en", name: "Athena", description: "Clear and authoritative female voice"),
        DeepgramVoice(id: "aura-2-hera-en", name: "Hera", description: "Rich and confident female voice"),
        DeepgramVoice(id: "aura-2-orion-en", name: "Orion", description: "Deep and steady male voice"),
        DeepgramVoice(id: "aura-2-arcas-en", name: "Arcas", description: "Friendly and conversational male voice"),
        DeepgramVoice(id: "aura-2-perseus-en", name: "Perseus", description: "Smooth and professional male voice"),
        DeepgramVoice(id: "aura-2-helios-en", name: "Helios", description: "Warm and inviting male voice"),
        DeepgramVoice(id: "aura-2-zeus-en", name: "Zeus", description: "Strong and commanding male voice"),
    ]
}

// MARK: - Errors

enum DeepgramTTSError: LocalizedError {
    case synthesizeFailed
    case invalidAPIKey
    case apiKeyMissing
    case rateLimited
    case emptyResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .synthesizeFailed: "Deepgram synthesis failed"
        case .invalidAPIKey: "Invalid Deepgram API key"
        case .apiKeyMissing: "Deepgram API key not configured"
        case .rateLimited: "Deepgram rate limit reached — wait a moment"
        case .emptyResponse: "Deepgram returned empty audio data"
        case .networkError(let msg): "Deepgram: \(msg)"
        }
    }
}
