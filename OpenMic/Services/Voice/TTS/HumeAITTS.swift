import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "HumeAITTS")

/// Hume AI Octave TTS engine with emotionally expressive voices.
/// Falls back to SystemTTS on failure.
@MainActor
final class HumeAITTS: NSObject, TTSEngineProtocol {
    private let apiKey: String
    private var voiceName: String?

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    init(
        apiKey: String,
        voiceName: String? = nil
    ) {
        self.apiKey = apiKey
        self.voiceName = voiceName
        super.init()
    }

    // MARK: - Configuration

    func setVoice(id: String) {
        self.voiceName = id
    }

    // MARK: - TTSEngineProtocol

    func speak(_ text: String) async {
        guard !text.isEmpty else { return }

        stop()
        try? AudioSessionManager.shared.configureForSpeaking()
        isSpeaking = true

        do {
            let audioData = try await synthesize(text: text)
            guard isSpeaking else { return }
            try await playAudio(data: audioData)
        } catch {
            log.error("Hume AI TTS failed: \(error.localizedDescription, privacy: .public) — falling back to system TTS")
            try? AudioSessionManager.shared.configureForSpeaking(.speechSynthesizer)
            await fallbackTTS.speak(text)
        }

        isSpeaking = false
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        audioPlayer?.stop()
        audioPlayer?.delegate = nil
        audioPlayer = nil
        playbackContinuation?.resume()
        playbackContinuation = nil
        fallbackTTS.stop()
        isSpeaking = false
    }

    // MARK: - Synthesis

    private func synthesize(text: String) async throws -> Data {
        guard let url = URL(string: "https://api.hume.ai/v0/tts/file") else {
            throw HumeAIError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Hume-Api-Key")

        var body: [String: Any] = [
            "text": text,
            "format": ["type": "mp3"]
        ]

        if let voiceName {
            body["voice"] = ["name": voiceName]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HumeAIError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw HumeAIError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw HumeAIError.rateLimited
            }
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            log.error("Hume AI TTS HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
            throw HumeAIError.synthesizeFailed
        }

        guard !data.isEmpty else {
            throw HumeAIError.emptyResponse
        }

        return data
    }

    // MARK: - Playback

    private func playAudio(data: Data) async throws {
        let player = try AVAudioPlayer(data: data)
        audioPlayer = player
        player.delegate = self
        player.prepareToPlay()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.playbackContinuation = continuation
            player.play()
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension HumeAITTS: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }
}
