import Foundation
import Testing
@testable import OpenMic

@Suite("Pipeline Voice Session")
struct PipelineVoiceSessionTests {
    @Test("Cancelled sendText does not persist a final assistant reply")
    @MainActor
    func cancelledSendTextDoesNotPersistFinalAssistantReply() async throws {
        let stt = MockSTTEngine()
        let tts = MockTTSEngine()
        let provider = ControlledAIProvider()
        let session = PipelineVoiceSession(
            sttEngine: stt,
            ttsEngine: tts,
            aiProvider: provider
        )
        let recorder = TranscriptRecorder()

        let transcriptTask = Task {
            for await transcript in session.transcriptStream {
                await recorder.append(transcript)
            }
        }

        let sendTask = Task {
            try await session.sendText("Hello")
        }

        try? await Task.sleep(for: .milliseconds(50))
        sendTask.cancel()
        provider.finish()

        let wasCancelled: Bool
        do {
            try await sendTask.value
            wasCancelled = false
        } catch is CancellationError {
            wasCancelled = true
        } catch {
            wasCancelled = false
        }
        #expect(wasCancelled)

        try? await Task.sleep(for: .milliseconds(50))

        let transcripts = await recorder.snapshot()
        #expect(
            transcripts.contains { transcript in
                transcript.role == .user
                    && transcript.isFinal
                    && transcript.text == "Hello"
            }
        )
        #expect(
            !transcripts.contains { transcript in
                transcript.role == .assistant && transcript.isFinal
            }
        )
        #expect(
            session.conversationHistory.filter { $0.role == .assistant }.isEmpty
        )

        transcriptTask.cancel()
        await session.stop()
    }

    @Test("sendText propagates provider errors without saving a final assistant reply")
    @MainActor
    func sendTextPropagatesProviderErrors() async throws {
        let stt = MockSTTEngine()
        let tts = MockTTSEngine()
        let provider = FailingAIProvider()
        let session = PipelineVoiceSession(
            sttEngine: stt,
            ttsEngine: tts,
            aiProvider: provider
        )

        let didThrow: Bool
        do {
            try await session.sendText("Hello")
            didThrow = false
        } catch {
            didThrow = true
        }
        #expect(didThrow)

        #expect(
            session.conversationHistory.filter { $0.role == .assistant }.isEmpty
        )

        let isErrorState: Bool
        if case .error = session.state {
            isErrorState = true
        } else {
            isErrorState = false
        }
        #expect(isErrorState)
    }

    @Test("Realtime session rejects unsupported providers")
    @MainActor
    func realtimeSessionRejectsUnsupportedProviders() {
        let rejectedUnsupportedProvider: Bool
        do {
            _ = try RealtimeVoiceSession(
                provider: .anthropic,
                proxyBaseURL: URL(string: "https://example.com")!,
                authToken: "token",
                deviceID: "device"
            )
            rejectedUnsupportedProvider = false
        } catch let error as RealtimeVoiceSessionError {
            if case .unsupportedProvider(.anthropic) = error {
                rejectedUnsupportedProvider = true
            } else {
                rejectedUnsupportedProvider = false
            }
        } catch {
            rejectedUnsupportedProvider = false
        }
        #expect(rejectedUnsupportedProvider)
    }
}

@MainActor
private final class MockSTTEngine: STTEngine {
    private(set) var isListening = false
    let transcriptStream: AsyncStream<VoiceTranscript>
    let audioLevelStream: AsyncStream<Float>

    init() {
        transcriptStream = AsyncStream { _ in }
        audioLevelStream = AsyncStream { _ in }
    }

    func startListening() async throws {
        isListening = true
    }

    func stopListening() async {
        isListening = false
    }
}

@MainActor
private final class MockTTSEngine: TTSEngineProtocol {
    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    func speak(_ text: String) async {
        _ = text
        isSpeaking = true
        isSpeaking = false
    }

    func stop() {
        isSpeaking = false
    }
}

private actor TranscriptRecorder {
    private var transcripts: [VoiceTranscript] = []

    func append(_ transcript: VoiceTranscript) {
        transcripts.append(transcript)
    }

    func snapshot() -> [VoiceTranscript] {
        transcripts
    }
}

private final class ControlledAIProvider: @unchecked Sendable, AIProvider {
    let providerType: AIProviderType = .openAI
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        _ = messages
        return AsyncThrowingStream { continuation in
            self.continuation = continuation
            continuation.yield("Partial reply")
        }
    }

    func validateKey() async throws -> Bool {
        true
    }

    func finish() {
        continuation?.finish()
        continuation = nil
    }
}

private struct FailingAIProvider: AIProvider {
    let providerType: AIProviderType = .openAI

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        _ = messages
        return AsyncThrowingStream { continuation in
            continuation.finish(
                throwing: AIProviderError.networkError("simulated failure")
            )
        }
    }

    func validateKey() async throws -> Bool {
        true
    }
}
