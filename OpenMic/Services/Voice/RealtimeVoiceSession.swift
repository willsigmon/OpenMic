import Foundation

/// Realtime voice session router — delegates to provider-specific session
/// (OpenAI Realtime, Gemini Live, Hume EVI 3, ElevenLabs Conv AI).
@MainActor
final class RealtimeVoiceSession: VoiceSessionProtocol {
    private let innerSession: any VoiceSessionProtocol

    private(set) var state: VoiceSessionState = .idle

    var stateStream: AsyncStream<VoiceSessionState> { innerSession.stateStream }
    var transcriptStream: AsyncStream<VoiceTranscript> { innerSession.transcriptStream }
    var audioLevelStream: AsyncStream<Float> { innerSession.audioLevelStream }

    init(
        provider: AIProviderType,
        proxyBaseURL: URL,
        authToken: String,
        deviceID: String,
        voice: String = "alloy"
    ) {
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
            // Fallback to OpenAI for unsupported realtime providers
            innerSession = OpenAIRealtimeSession(
                proxyBaseURL: proxyBaseURL,
                authToken: authToken,
                deviceID: deviceID,
                voice: voice
            )
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
