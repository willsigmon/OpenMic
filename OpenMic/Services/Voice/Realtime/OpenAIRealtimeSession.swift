import Foundation

/// OpenAI Realtime API voice session via WebSocket (through Supabase proxy).
/// Sends PCM16 audio chunks, receives audio + text deltas.
@MainActor
final class OpenAIRealtimeSession: VoiceSessionProtocol {
    private let proxyURL: URL
    private let voice: String
    private let model: String
    private let authToken: String

    private var webSocketTask: URLSessionWebSocketTask?
    private var audioIO: RealtimeAudioIO?
    private var receiveTask: Task<Void, Never>?

    private var stateContinuation: AsyncStream<VoiceSessionState>.Continuation?
    private var transcriptContinuation: AsyncStream<VoiceTranscript>.Continuation?
    private var audioLevelContinuation: AsyncStream<Float>.Continuation?
    private var audioLevelForwardTask: Task<Void, Never>?

    private(set) var state: VoiceSessionState = .idle

    let stateStream: AsyncStream<VoiceSessionState>
    let transcriptStream: AsyncStream<VoiceTranscript>
    let audioLevelStream: AsyncStream<Float>

    init(
        proxyBaseURL: URL,
        authToken: String,
        deviceID: String,
        voice: String = "alloy",
        model: String = "gpt-4o-realtime-preview"
    ) {
        self.voice = voice
        self.model = model
        self.authToken = authToken

        var components = URLComponents(url: proxyBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: "openai_realtime"),
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "device_id", value: deviceID),
        ]
        self.proxyURL = components.url!

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
    }

    // MARK: - VoiceSessionProtocol

    func start(systemPrompt: String) async throws {
        try AudioSessionManager.shared.configureForVoiceChat()
        updateState(.listening)

        // Connect WebSocket to proxy
        var request = URLRequest(url: proxyURL)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        let wsTask = session.webSocketTask(with: request)
        wsTask.resume()
        self.webSocketTask = wsTask

        // Send session configuration
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": systemPrompt,
                "voice": voice,
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1",
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500,
                ],
            ] as [String: Any],
        ]

        if let data = try? JSONSerialization.data(withJSONObject: sessionConfig),
           let jsonString = String(data: data, encoding: .utf8)
        {
            try? await wsTask.send(.string(jsonString))
        }

        // Start audio capture
        let io = RealtimeAudioIO()
        self.audioIO = io

        // Forward audio levels
        audioLevelForwardTask = Task { [weak self] in
            for await level in io.audioLevelStream {
                guard let self, !Task.isCancelled else { break }
                self.audioLevelContinuation?.yield(level)
            }
        }

        try io.startCapture { [weak self] pcmData in
            guard let self else { return }
            self.sendAudioChunk(pcmData)
        }

        // Start receiving server messages
        receiveTask = Task { [weak self] in
            guard let self else { return }
            await self.receiveLoop()
        }
    }

    func stop() async {
        receiveTask?.cancel()
        audioLevelForwardTask?.cancel()
        audioIO?.stopCapture()
        audioIO = nil

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        updateState(.idle)
        stateContinuation?.finish()
        transcriptContinuation?.finish()
        audioLevelContinuation?.finish()

        try? AudioSessionManager.shared.deactivate()
    }

    func interrupt() async {
        audioIO?.clearPlaybackQueue()

        // Send response.cancel to server
        let cancel = ["type": "response.cancel"]
        if let data = try? JSONSerialization.data(withJSONObject: cancel),
           let jsonString = String(data: data, encoding: .utf8)
        {
            try? await webSocketTask?.send(.string(jsonString))
        }

        updateState(.listening)
    }

    // MARK: - Audio Sending

    private func sendAudioChunk(_ data: Data) {
        let base64 = data.base64EncodedString()
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64,
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            Task {
                try? await webSocketTask?.send(.string(jsonString))
            }
        }
    }

    // MARK: - Message Receiving

    private func receiveLoop() async {
        guard let ws = webSocketTask else { return }

        var currentResponseText = ""

        while !Task.isCancelled {
            do {
                let message = try await ws.receive()

                switch message {
                case .string(let text):
                    guard let data = text.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let type = json["type"] as? String
                    else { continue }

                    switch type {
                    case "input_audio_buffer.speech_started":
                        updateState(.listening)
                        audioIO?.clearPlaybackQueue()

                    case "input_audio_buffer.speech_stopped":
                        updateState(.processing)

                    case "response.audio_transcript.delta":
                        if let delta = json["delta"] as? String {
                            currentResponseText += delta
                            transcriptContinuation?.yield(
                                VoiceTranscript(
                                    text: currentResponseText,
                                    isFinal: false,
                                    role: .assistant
                                )
                            )
                        }

                    case "response.audio.delta":
                        updateState(.speaking)
                        if let delta = json["delta"] as? String,
                           let audioData = Data(base64Encoded: delta)
                        {
                            audioIO?.playAudioChunk(audioData)
                        }

                    case "response.audio_transcript.done":
                        if let transcript = json["transcript"] as? String {
                            transcriptContinuation?.yield(
                                VoiceTranscript(
                                    text: transcript,
                                    isFinal: true,
                                    role: .assistant
                                )
                            )
                            currentResponseText = ""
                        }

                    case "conversation.item.input_audio_transcription.completed":
                        if let transcript = json["transcript"] as? String {
                            transcriptContinuation?.yield(
                                VoiceTranscript(
                                    text: transcript,
                                    isFinal: true,
                                    role: .user
                                )
                            )
                        }

                    case "response.done":
                        updateState(.listening)
                        currentResponseText = ""

                    case "error":
                        if let error = json["error"] as? [String: Any],
                           let msg = error["message"] as? String
                        {
                            updateState(.error(msg))
                        }

                    default:
                        break
                    }

                case .data:
                    // Binary frames not expected from OpenAI
                    break

                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    updateState(.error("Connection lost"))
                }
                break
            }
        }
    }

    // MARK: - State

    private func updateState(_ newState: VoiceSessionState) {
        state = newState
        stateContinuation?.yield(newState)
    }
}
