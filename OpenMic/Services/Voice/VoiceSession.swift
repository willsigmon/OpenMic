import Foundation

enum VoiceSessionState: Sendable, Equatable {
    case idle
    case listening
    case processing
    case speaking
    case error(String)

    var isActive: Bool {
        switch self {
        case .listening, .processing, .speaking: true
        default: false
        }
    }
}

struct VoiceTranscript: Sendable {
    let text: String
    let isFinal: Bool
    let role: MessageRole
}

@MainActor
protocol VoiceSessionProtocol: AnyObject {
    var state: VoiceSessionState { get }
    var stateStream: AsyncStream<VoiceSessionState> { get }
    var transcriptStream: AsyncStream<VoiceTranscript> { get }
    var audioLevelStream: AsyncStream<Float> { get }

    func start(systemPrompt: String) async throws
    func stop() async
    func interrupt() async
}
