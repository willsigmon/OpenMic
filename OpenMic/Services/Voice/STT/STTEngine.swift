import Foundation

@MainActor
protocol STTEngine: AnyObject {
    var isListening: Bool { get }
    var transcriptStream: AsyncStream<VoiceTranscript> { get }
    var audioLevelStream: AsyncStream<Float> { get }

    func startListening() async throws
    func stopListening() async
}
