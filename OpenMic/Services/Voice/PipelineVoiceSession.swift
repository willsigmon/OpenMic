import Foundation

@MainActor
final class PipelineVoiceSession: VoiceSessionProtocol {
    private let sttEngine: STTEngine
    private let ttsEngine: TTSEngineProtocol
    private let aiProvider: AIProvider
    private let systemPrompt: String

    private var stateContinuation: AsyncStream<VoiceSessionState>.Continuation?
    private var transcriptContinuation: AsyncStream<VoiceTranscript>.Continuation?
    private var audioLevelContinuation: AsyncStream<Float>.Continuation?
    private var routeChangeObserver: NSObjectProtocol?

    private var listeningTask: Task<Void, Never>?
    private(set) var conversationHistory: [(role: MessageRole, content: String)] = []

    private(set) var state: VoiceSessionState = .idle
    private let handoffDelay: Duration = .milliseconds(120)

    let stateStream: AsyncStream<VoiceSessionState>
    let transcriptStream: AsyncStream<VoiceTranscript>
    let audioLevelStream: AsyncStream<Float>

    init(
        sttEngine: STTEngine,
        ttsEngine: TTSEngineProtocol,
        aiProvider: AIProvider,
        systemPrompt: String = ""
    ) {
        self.sttEngine = sttEngine
        self.ttsEngine = ttsEngine
        self.aiProvider = aiProvider
        self.systemPrompt = systemPrompt

        var stateCont: AsyncStream<VoiceSessionState>.Continuation!
        self.stateStream = AsyncStream { stateCont = $0 }
        self.stateContinuation = stateCont

        var transcriptCont: AsyncStream<VoiceTranscript>.Continuation!
        self.transcriptStream = AsyncStream { transcriptCont = $0 }
        self.transcriptContinuation = transcriptCont

        var audioLevelCont: AsyncStream<Float>.Continuation!
        self.audioLevelStream = AsyncStream { audioLevelCont = $0 }
        self.audioLevelContinuation = audioLevelCont
    }

    deinit {
        stateContinuation?.finish()
        transcriptContinuation?.finish()
        audioLevelContinuation?.finish()
        listeningTask?.cancel()
    }

    func seedHistory(_ messages: [(role: MessageRole, content: String)]) {
        conversationHistory = messages
    }

    func start(systemPrompt: String) async throws {
        try AudioSessionManager.shared.configureForListening()
        setUpAudioObservers()

        let prompt = systemPrompt.isEmpty ? self.systemPrompt : systemPrompt
        if !prompt.isEmpty {
            conversationHistory.append((.system, prompt))
        }

        startListeningLoop()
    }

    func stop() async {
        listeningTask?.cancel()
        listeningTask = nil
        await sttEngine.stopListening()
        ttsEngine.stop()
        tearDownAudioObservers()
        updateState(.idle)
        try? AudioSessionManager.shared.deactivate()
    }

    func interrupt() async {
        ttsEngine.stop()
        updateState(.listening)
    }

    /// Send text directly to AI (skipping STT), then speak the response.
    /// After the AI responds via TTS, transitions to the normal listening loop.
    func sendText(_ text: String, systemPrompt override: String? = nil) async {
        // Initialize system prompt if this is the first interaction
        if conversationHistory.isEmpty {
            let prompt = override ?? systemPrompt
            if !prompt.isEmpty {
                conversationHistory.append((.system, prompt))
            }
        }

        updateState(.processing)
        conversationHistory.append((.user, text))
        transcriptContinuation?.yield(
            VoiceTranscript(text: text, isFinal: true, role: .user)
        )

        do {
            var fullResponse = ""
            let stream = try await aiProvider.streamChat(
                messages: conversationHistory.map {
                    ChatMessage(role: $0.role, content: $0.content)
                }
            )

            try? AudioSessionManager.shared.configureForSpeaking(ttsEngine.audioRequirement)
            updateState(.speaking)

            var sentenceBuffer = ""
            for try await chunk in stream {
                if Task.isCancelled { break }
                fullResponse += chunk
                sentenceBuffer += chunk
                transcriptContinuation?.yield(
                    VoiceTranscript(
                        text: fullResponse,
                        isFinal: false,
                        role: .assistant
                    )
                )

                if let range = sentenceBuffer.range(
                    of: "[.!?] ",
                    options: .regularExpression
                ) {
                    let sentence = String(sentenceBuffer[..<range.upperBound])
                    sentenceBuffer = String(sentenceBuffer[range.upperBound...])
                    await ttsEngine.speak(sentence)
                }
            }

            if !sentenceBuffer.isEmpty {
                await ttsEngine.speak(sentenceBuffer)
            }

            conversationHistory.append((.assistant, fullResponse))
            transcriptContinuation?.yield(
                VoiceTranscript(text: fullResponse, isFinal: true, role: .assistant)
            )

            // Return to listening after speaking
            startListeningLoop()
        } catch {
            updateState(.error(error.localizedDescription))
        }
    }

    private func startListeningLoop() {
        // Cancel any existing loop before starting a new one
        listeningTask?.cancel()

        listeningTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                updateState(.listening)
                try? AudioSessionManager.shared.configureForListening()

                do {
                    try await sttEngine.startListening()
                } catch {
                    try? AudioSessionManager.shared.deactivate()
                    updateState(.error(error.localizedDescription))
                    return
                }

                // Forward audio levels
                let levelTask = Task { [weak self] in
                    guard let self else { return }
                    for await level in sttEngine.audioLevelStream {
                        if Task.isCancelled { break }
                        audioLevelContinuation?.yield(level)
                    }
                }
                defer { levelTask.cancel() }

                // Wait for final transcript
                var finalText = ""
                for await transcript in sttEngine.transcriptStream {
                    transcriptContinuation?.yield(transcript)
                    if transcript.isFinal {
                        finalText = transcript.text
                        break
                    }
                }

                await sttEngine.stopListening()

                let trimmedFinalText = finalText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard trimmedFinalText.count >= 2, !Task.isCancelled else {
                    continue
                }

                try? await Task.sleep(for: handoffDelay)
                guard !Task.isCancelled else { continue }

                // Process through AI
                updateState(.processing)
                conversationHistory.append((.user, trimmedFinalText))

                do {
                    var fullResponse = ""
                    let stream = try await aiProvider.streamChat(
                        messages: conversationHistory.map {
                            ChatMessage(role: $0.role, content: $0.content)
                        }
                    )

                    try? AudioSessionManager.shared.configureForSpeaking(ttsEngine.audioRequirement)
                    updateState(.speaking)

                    // Collect response and speak in sentence chunks
                    var sentenceBuffer = ""
                    for try await chunk in stream {
                        if Task.isCancelled { break }
                        fullResponse += chunk
                        sentenceBuffer += chunk
                        transcriptContinuation?.yield(
                            VoiceTranscript(
                                text: fullResponse,
                                isFinal: false,
                                role: .assistant
                            )
                        )

                        // Speak when we hit sentence boundaries
                        if let range = sentenceBuffer.range(
                            of: "[.!?] ",
                            options: .regularExpression
                        ) {
                            let sentence = String(
                                sentenceBuffer[..<range.upperBound]
                            )
                            sentenceBuffer = String(
                                sentenceBuffer[range.upperBound...]
                            )
                            await ttsEngine.speak(sentence)
                        }
                    }

                    // Speak remaining text
                    if !sentenceBuffer.isEmpty {
                        await ttsEngine.speak(sentenceBuffer)
                    }

                    conversationHistory.append((.assistant, fullResponse))
                    transcriptContinuation?.yield(
                        VoiceTranscript(
                            text: fullResponse,
                            isFinal: true,
                            role: .assistant
                        )
                    )
                } catch {
                    updateState(.error(error.localizedDescription))
                }
            }
        }
    }

    private func updateState(_ newState: VoiceSessionState) {
        state = newState
        stateContinuation?.yield(newState)
    }

    private func setUpAudioObservers() {
        guard routeChangeObserver == nil else { return }
        routeChangeObserver = AudioSessionManager.shared.observeRouteChanges { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state.isActive else { return }
                if self.state == .speaking {
                    try? AudioSessionManager.shared.configureForSpeaking(self.ttsEngine.audioRequirement)
                } else {
                    try? AudioSessionManager.shared.configureForListening()
                }
            }
        }
    }

    private func tearDownAudioObservers() {
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
            self.routeChangeObserver = nil
        }
    }
}
