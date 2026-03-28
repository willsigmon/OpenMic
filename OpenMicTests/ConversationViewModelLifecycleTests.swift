import Foundation
import Testing
@testable import OpenMic

@Suite("Conversation ViewModel Lifecycle")
struct ConversationViewModelLifecycleTests {
    @Test("Cancelled start does not clobber the replacement session")
    @MainActor
    func cancelledStartDoesNotClobberReplacementSession() async throws {
        let services = try makeAppServices()
        let gate = AsyncGate()
        let firstSession = TestVoiceSession(name: "first")
        let secondSession = TestVoiceSession(name: "second")
        let builder = SequencedSessionBuilder(steps: [
            .gated(
                gate,
                build: ConversationSessionBuild(
                    voiceSession: firstSession,
                    pipelineSession: nil,
                    provider: .openAI,
                    providerFallbackMessage: nil,
                    isRealtimeSession: false
                )
            ),
            .immediate(
                ConversationSessionBuild(
                    voiceSession: secondSession,
                    pipelineSession: nil,
                    provider: .openAI,
                    providerFallbackMessage: nil,
                    isRealtimeSession: false
                )
            ),
        ])
        let viewModel = ConversationViewModel(
            appServices: services,
            sessionBuilder: { try await builder.nextBuild() }
        )

        viewModel.startListening()
        await waitUntil("first build started") {
            builder.requestCount == 1
        }

        viewModel.stopListening()
        viewModel.startListening()

        await waitUntil("replacement session started") {
            secondSession.startCallCount == 1
        }

        await gate.open()

        await waitUntil("stale session torn down") {
            firstSession.stopCallCount == 1
        }

        #expect(firstSession.startCallCount == 0)
        #expect(secondSession.startCallCount == 1)
        #expect(viewModel.conversation != nil)

        viewModel.stopListening()
        await waitUntil("replacement session stopped") {
            secondSession.stopCallCount == 1
        }
    }

    @Test("Switching provider waits for teardown before restarting")
    @MainActor
    func switchProviderWaitsForTeardownBeforeRestarting() async throws {
        let services = try makeAppServices()
        let firstSession = TestVoiceSession(name: "openai")
        let secondSession = TestVoiceSession(name: "anthropic")
        let builder = SequencedSessionBuilder(steps: [
            .immediate(
                ConversationSessionBuild(
                    voiceSession: firstSession,
                    pipelineSession: nil,
                    provider: .openAI,
                    providerFallbackMessage: nil,
                    isRealtimeSession: false
                )
            ),
            .immediate(
                ConversationSessionBuild(
                    voiceSession: secondSession,
                    pipelineSession: nil,
                    provider: .anthropic,
                    providerFallbackMessage: nil,
                    isRealtimeSession: false
                )
            ),
        ])
        let viewModel = ConversationViewModel(
            appServices: services,
            sessionBuilder: { try await builder.nextBuild() }
        )

        viewModel.startListening()
        await waitUntil("initial session started") {
            firstSession.startCallCount == 1
        }

        viewModel.switchProvider(to: AIProviderType.anthropic)

        await waitUntil("replacement provider session started") {
            firstSession.stopCallCount == 1
                && secondSession.startCallCount == 1
                && viewModel.activeProvider == AIProviderType.anthropic
        }

        #expect(
            viewModel.bubbles.contains {
                $0.role == MessageRole.system && $0.text.contains("Switched to")
            }
        )

        viewModel.stopListening()
        await waitUntil("replacement provider session stopped") {
            secondSession.stopCallCount == 1
        }
    }

    @Test("Immediate restart after stopListening preserves usage tracking for the replacement session")
    @MainActor
    func immediateRestartAfterStopListeningKeepsReplacementUsageTrackingActive() async throws {
        let services = try makeAppServices()
        let firstSession = TestVoiceSession(name: "first")
        let secondSession = TestVoiceSession(name: "second")
        let builder = SequencedSessionBuilder(steps: [
            .immediate(
                ConversationSessionBuild(
                    voiceSession: firstSession,
                    pipelineSession: nil,
                    provider: .openAI,
                    providerFallbackMessage: nil,
                    isRealtimeSession: false
                )
            ),
            .immediate(
                ConversationSessionBuild(
                    voiceSession: secondSession,
                    pipelineSession: nil,
                    provider: .openAI,
                    providerFallbackMessage: nil,
                    isRealtimeSession: false
                )
            ),
        ])
        let viewModel = ConversationViewModel(
            appServices: services,
            sessionBuilder: { try await builder.nextBuild() }
        )

        viewModel.startListening()
        await waitUntil("first session started") {
            firstSession.startCallCount == 1
                && services.usageTracker.isSessionActive
                && services.usageTracker.sessionCount == 1
        }

        viewModel.stopListening()
        viewModel.startListening()

        await waitUntil("replacement session started") {
            secondSession.startCallCount == 1
                && services.usageTracker.isSessionActive
                && services.usageTracker.sessionCount == 2
                && services.usageTracker.currentSessionStart != nil
        }

        await waitUntil("first session stopped") {
            firstSession.stopCallCount == 1
        }

        #expect(services.usageTracker.isSessionActive)
        #expect(services.usageTracker.sessionCount == 2)
        #expect(services.usageTracker.currentSessionStart != nil)

        viewModel.stopListening()
        await waitUntil("replacement session stopped") {
            secondSession.stopCallCount == 1
        }
        #expect(!services.usageTracker.isSessionActive)
        #expect(services.usageTracker.currentSessionStart == nil)
    }

    @Test("sendPrompt cancels a pending start before building its own session")
    @MainActor
    func sendPromptCancelsPendingStartBeforeCreatingOwnSession() async throws {
        let services = try makeAppServices()
        let gate = AsyncGate()
        let firstSession = TestVoiceSession(name: "pending-start")
        let secondSession = TestVoiceSession(name: "send-prompt")
        let builder = SequencedSessionBuilder(steps: [
            .gated(
                gate,
                build: ConversationSessionBuild(
                    voiceSession: firstSession,
                    pipelineSession: nil,
                    provider: .openAI,
                    providerFallbackMessage: nil,
                    isRealtimeSession: false
                )
            ),
            .immediate(
                ConversationSessionBuild(
                    voiceSession: secondSession,
                    pipelineSession: nil,
                    provider: .openAI,
                    providerFallbackMessage: nil,
                    isRealtimeSession: false
                )
            ),
        ])
        let viewModel = ConversationViewModel(
            appServices: services,
            sessionBuilder: { try await builder.nextBuild() }
        )

        viewModel.startListening()
        await waitUntil("pending start requested") {
            builder.requestCount == 1
        }

        viewModel.sendPrompt("Hello")

        await waitUntil("prompt session started") {
            secondSession.startCallCount == 1
        }

        await gate.open()

        await waitUntil("stale start session torn down") {
            firstSession.stopCallCount == 1
        }

        #expect(firstSession.startCallCount == 0)
        #expect(secondSession.startCallCount == 1)
        #expect(viewModel.conversation != nil)

        viewModel.stopListening()
        await waitUntil("prompt session stopped") {
            secondSession.stopCallCount == 1
        }
    }
}

@MainActor
private final class TestVoiceSession: VoiceSessionProtocol {
    let name: String

    private(set) var state: VoiceSessionState = .idle
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var interruptCallCount = 0

    let stateStream: AsyncStream<VoiceSessionState>
    let transcriptStream: AsyncStream<VoiceTranscript>
    let audioLevelStream: AsyncStream<Float>

    private let stateContinuation: AsyncStream<VoiceSessionState>.Continuation

    init(name: String) {
        self.name = name

        var stateContinuation: AsyncStream<VoiceSessionState>.Continuation!
        self.stateStream = AsyncStream { stateContinuation = $0 }
        self.stateContinuation = stateContinuation

        self.transcriptStream = AsyncStream { _ in }
        self.audioLevelStream = AsyncStream { _ in }
    }

    func start(systemPrompt: String) async throws {
        _ = systemPrompt
        startCallCount += 1
        state = .listening
        stateContinuation.yield(.listening)
    }

    func stop() async {
        stopCallCount += 1
        state = .idle
        stateContinuation.yield(.idle)
    }

    func interrupt() async {
        interruptCallCount += 1
    }
}

private actor AsyncGate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let continuations = waiters
        waiters.removeAll()
        continuations.forEach { $0.resume() }
    }
}

@MainActor
private final class SequencedSessionBuilder {
    enum Step {
        case immediate(ConversationSessionBuild)
        case gated(AsyncGate, build: ConversationSessionBuild)
    }

    private var steps: [Step]
    private(set) var requestCount = 0

    init(steps: [Step]) {
        self.steps = steps
    }

    func nextBuild() async throws -> ConversationSessionBuild {
        requestCount += 1
        guard !steps.isEmpty else {
            Issue.record("Session builder ran out of prepared steps")
            throw CancellationError()
        }
        let step = steps.removeFirst()
        switch step {
        case .immediate(let build):
            return build
        case .gated(let gate, let build):
            await gate.wait()
            return build
        }
    }
}

private func waitUntil(
    _ description: String,
    timeout: Duration = .seconds(2),
    pollInterval: Duration = .milliseconds(20),
    condition: @escaping @MainActor () async -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() {
            return
        }
        try? await Task.sleep(for: pollInterval)
    }
    Issue.record("Timed out waiting for \(description)")
}

@MainActor
private func makeAppServices() throws -> AppServices {
    let services = try AppServices.makeForTesting()
    services.conversationStore.deleteAllConversations()
    return services
}
