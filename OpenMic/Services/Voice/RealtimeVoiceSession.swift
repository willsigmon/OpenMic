import Foundation

enum RealtimeVoiceSessionError: LocalizedError {
    case unsupportedProvider(AIProviderType)

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let provider):
            return "\(provider.displayName) does not support realtime voice yet"
        }
    }
}

/// Realtime voice session router for supported managed realtime providers.
@MainActor
final class RealtimeVoiceSession: VoiceSessionProtocol {
    private let innerSession: any VoiceSessionProtocol

    var state: VoiceSessionState { innerSession.state }

    var stateStream: AsyncStream<VoiceSessionState> { innerSession.stateStream }
    var transcriptStream: AsyncStream<VoiceTranscript> { innerSession.transcriptStream }
    var audioLevelStream: AsyncStream<Float> { innerSession.audioLevelStream }

    init(
        provider: AIProviderType,
        proxyBaseURL: URL,
        authToken: String,
        deviceID: String,
        voice: String = "alloy"
    ) throws {
        switch provider {
        case .openAI:
            innerSession = OpenAIRealtimeSession(
                proxyBaseURL: proxyBaseURL,
                authToken: authToken,
                deviceID: deviceID,
                voice: voice
            )

        case .gemini:
            // Gemini Live — use same proxy with different provider param
            innerSession = OpenAIRealtimeSession(
                proxyBaseURL: proxyBaseURL,
                authToken: authToken,
                deviceID: deviceID,
                voice: voice,
                model: "gemini-2.0-flash-live-001"
            )

        default:
            throw RealtimeVoiceSessionError.unsupportedProvider(provider)
        }
    }

    func start(systemPrompt: String) async throws {
        try await innerSession.start(systemPrompt: systemPrompt)
    }

    func stop() async {
        await innerSession.stop()
    }

    func interrupt() async {
        await innerSession.interrupt()
    }
}
