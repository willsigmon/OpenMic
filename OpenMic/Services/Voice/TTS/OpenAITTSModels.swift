import Foundation

// MARK: - OpenAI TTS Voice

enum OpenAITTSVoice: String, CaseIterable, Codable, Sendable, Identifiable {
    case alloy
    case ash
    case ballad
    case coral
    case echo
    case fable
    case nova
    case onyx
    case sage
    case shimmer

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var description: String {
        switch self {
        case .alloy: "Neutral and balanced"
        case .ash: "Warm and conversational"
        case .ballad: "Soft and melodic"
        case .coral: "Clear and friendly"
        case .echo: "Smooth and resonant"
        case .fable: "Expressive and dynamic"
        case .nova: "Natural and energetic"
        case .onyx: "Deep and authoritative"
        case .sage: "Calm and thoughtful"
        case .shimmer: "Bright and upbeat"
        }
    }
}

// MARK: - OpenAI TTS Model

enum OpenAITTSModel: String, CaseIterable, Codable, Sendable, Identifiable {
    case tts1 = "tts-1"
    case tts1HD = "tts-1-hd"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tts1: "Standard"
        case .tts1HD: "HD"
        }
    }

    var subtitle: String {
        switch self {
        case .tts1: "~500ms — Optimized for real-time, lower latency"
        case .tts1HD: "~800ms — Higher fidelity audio quality"
        }
    }
}

// MARK: - Errors

enum OpenAITTSError: LocalizedError {
    case synthesizeFailed
    case invalidAPIKey
    case apiKeyMissing
    case rateLimited
    case emptyResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .synthesizeFailed: "OpenAI TTS synthesis failed"
        case .invalidAPIKey: "Invalid OpenAI API key"
        case .apiKeyMissing: "OpenAI API key not configured"
        case .rateLimited: "OpenAI rate limit reached — wait a moment"
        case .emptyResponse: "OpenAI returned empty audio data"
        case .networkError(let msg): "OpenAI TTS: \(msg)"
        }
    }
}
