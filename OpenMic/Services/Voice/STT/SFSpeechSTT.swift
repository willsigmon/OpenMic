import Foundation
import Speech
import AVFoundation

@MainActor
final class SFSpeechSTT: STTEngine {
    private let speechRecognizer: SFSpeechRecognizer?
    private let endpointingConfig: SpeechEndpointingConfig
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var finalizationFallbackTask: Task<Void, Never>?
    private let audioEngine = AVAudioEngine()
    private var latestTranscriptText = ""
    private var hasEmittedTerminalTranscript = false

    private var transcriptContinuation: AsyncStream<VoiceTranscript>.Continuation?
    private var audioLevelContinuation: AsyncStream<Float>.Continuation?

    private(set) var isListening = false

    let transcriptStream: AsyncStream<VoiceTranscript>
    let audioLevelStream: AsyncStream<Float>

    init(
        locale: Locale = .current,
        paceProfile: SpeechPaceProfile = .fast
    ) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer()
        self.endpointingConfig = .forProfile(paceProfile)

        var transcriptCont: AsyncStream<VoiceTranscript>.Continuation!
        self.transcriptStream = AsyncStream { transcriptCont = $0 }
        self.transcriptContinuation = transcriptCont

        var audioLevelCont: AsyncStream<Float>.Continuation!
        self.audioLevelStream = AsyncStream { audioLevelCont = $0 }
        self.audioLevelContinuation = audioLevelCont
    }

    func startListening() async throws {
        guard !isListening else { return }
        cancelFinalizationFallback()
        latestTranscriptText = ""
        hasEmittedTerminalTranscript = false

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw STTError.speechRecognizerUnavailable
        }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw STTError.notAuthorized
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw STTError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        recognitionRequest.taskHint = .dictation

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let startFallback: @Sendable () -> Void = { [weak self] in
            Task { @MainActor [weak self] in
                self?.startFinalizationFallback()
            }
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat,
            block: makeAudioTapBlock(
                request: recognitionRequest,
                audioLevelContinuation: audioLevelContinuation,
                config: endpointingConfig,
                onDidRequestEndAudio: startFallback
            )
        )

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            cleanupRecognition()
            throw error
        }

        isListening = true

        recognitionTask = speechRecognizer.recognitionTask(
            with: recognitionRequest,
            resultHandler: { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let result {
                        let text = result.bestTranscription.formattedString
                        latestTranscriptText = text

                        if result.isFinal {
                            emitTerminalTranscriptIfNeeded(text: text)
                        } else {
                            transcriptContinuation?.yield(
                                VoiceTranscript(
                                    text: text,
                                    isFinal: false,
                                    role: .user
                                )
                            )
                        }
                    }

                    if error != nil {
                        cancelFinalizationFallback()
                        emitTerminalTranscriptIfNeeded(text: "")
                        cleanupRecognition()
                    } else if result?.isFinal == true {
                        cancelFinalizationFallback()
                        cleanupRecognition()
                    }
                }
            }
        )
    }

    func stopListening() async {
        cleanupRecognition()
    }

    private func cleanupRecognition() {
        cancelFinalizationFallback()

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        isListening = false
        latestTranscriptText = ""
    }

    private func startFinalizationFallback() {
        finalizationFallbackTask?.cancel()
        finalizationFallbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(
                for: .seconds(endpointingConfig.postEndFinalResultTimeout)
            )
            guard !Task.isCancelled else { return }
            let finalText = latestTranscriptText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            emitTerminalTranscriptIfNeeded(text: finalText)
            cleanupRecognition()
        }
    }

    private func cancelFinalizationFallback() {
        finalizationFallbackTask?.cancel()
        finalizationFallbackTask = nil
    }

    private func emitTerminalTranscriptIfNeeded(text: String) {
        guard !hasEmittedTerminalTranscript else { return }
        hasEmittedTerminalTranscript = true
        transcriptContinuation?.yield(
            VoiceTranscript(
                text: text,
                isFinal: true,
                role: .user
            )
        )
    }

}

private func makeAudioTapBlock(
    request: SFSpeechAudioBufferRecognitionRequest,
    audioLevelContinuation: AsyncStream<Float>.Continuation?,
    config: SpeechEndpointingConfig,
    onDidRequestEndAudio: @escaping @Sendable () -> Void
) -> AVAudioNodeTapBlock {
    var endpointDetector = VoiceEndpointDetector(config: config)
    var hasEndedAudio = false

    return { buffer, _ in
        guard !hasEndedAudio else { return }
        request.append(buffer)

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        let db = 20 * log10(max(rms, 0.000001))
        let normalized = max(0, min(1, (db + 60) / 60))
        audioLevelContinuation?.yield(normalized)
        let seconds = Double(frameCount) / buffer.format.sampleRate
        let action = endpointDetector.ingest(
            normalizedLevel: normalized,
            duration: seconds
        )

        if action == .endAudio {
            hasEndedAudio = true
            request.endAudio()
            onDidRequestEndAudio()
        }
    }
}

enum STTError: LocalizedError {
    case speechRecognizerUnavailable
    case requestCreationFailed
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .speechRecognizerUnavailable: "Speech recognizer is not available"
        case .requestCreationFailed: "Failed to create recognition request"
        case .notAuthorized: "Speech recognition not authorized"
        }
    }
}
