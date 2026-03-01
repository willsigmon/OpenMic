import AVFoundation
import os.log

private let ttsLog = Logger(subsystem: "com.willsigmon.openmic", category: "SystemTTS")

@MainActor
final class SystemTTS: NSObject, TTSEngineProtocol {
    private let synthesizer = AVSpeechSynthesizer()
    private var voiceIdentifier: String?
    private var speakingContinuation: CheckedContinuation<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .speechSynthesizer

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func setVoice(identifier: String?) {
        self.voiceIdentifier = identifier
    }

    func speak(_ text: String) async {
        guard !text.isEmpty else { return }

        stop()
        try? AudioSessionManager.shared.configureForSpeaking(.speechSynthesizer)

        let storedRate = UserDefaults.standard.float(forKey: "systemTTSSpeechRate")
        let storedPitch = UserDefaults.standard.float(forKey: "systemTTSPitch")

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = storedRate > 0 ? storedRate : AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = storedPitch > 0 ? storedPitch : 1.0
        utterance.volume = 1.0

        if let voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        isSpeaking = true
        ttsLog.info("speak() starting: \"\(text.prefix(60), privacy: .public)\"")

        await withCheckedContinuation { continuation in
            self.speakingContinuation = continuation
            self.synthesizer.speak(utterance)

            // Safety: if delegate never fires, resume after 15 seconds
            // to prevent permanent freeze.
            self.timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                if self?.speakingContinuation != nil {
                    ttsLog.warning("speak() timed out — delegate never fired, force-resuming")
                    self?.completeSpeaking()
                }
            }
        }

        isSpeaking = false
        ttsLog.info("speak() finished")
    }

    func stop() {
        timeoutTask?.cancel()
        timeoutTask = nil
        completeSpeaking()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func completeSpeaking() {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let continuation = speakingContinuation else { return }
        speakingContinuation = nil
        isSpeaking = false
        continuation.resume()
    }
}

extension SystemTTS: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        ttsLog.info("delegate: didStart")
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        ttsLog.info("delegate: didFinish")
        Task { @MainActor in
            self.completeSpeaking()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        ttsLog.info("delegate: didCancel")
        Task { @MainActor in
            self.completeSpeaking()
        }
    }
}
