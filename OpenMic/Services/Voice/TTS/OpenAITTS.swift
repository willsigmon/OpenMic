import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "OpenAITTS")

/// OpenAI TTS engine using the /v1/audio/speech endpoint.
/// Reuses the existing OpenAI API key from keychain.
/// Falls back to SystemTTS on failure.
@MainActor
final class OpenAITTS: NSObject, TTSEngineProtocol {
    private let apiKey: String
    private var voice: OpenAITTSVoice
    private var model: OpenAITTSModel

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    init(
        apiKey: String,
        voice: OpenAITTSVoice = .nova,
        model: OpenAITTSModel = .tts1
    ) {
        self.apiKey = apiKey
        self.voice = voice
        self.model = model
        super.init()
    }

    // MARK: - Configuration

    func setVoice(_ voiceName: String) {
        if let v = OpenAITTSVoice(rawValue: voiceName) {
            self.voice = v
        }
    }

    func setModel(_ model: OpenAITTSModel) {
        self.model = model
    }

    // MARK: - TTSEngineProtocol

    func speak(_ text: String) async {
        guard !text.isEmpty else { return }

        stop()
        try? AudioSessionManager.shared.configureForSpeaking()
        isSpeaking = true

        currentTask = Task {
            do {
                let audioData = try await synthesize(text: text)
                guard !Task.isCancelled, isSpeaking else { return }
                try await playAudio(data: audioData)
            } catch {
                guard !Task.isCancelled else { return }
                log.error("OpenAI TTS failed: \(error.localizedDescription, privacy: .public) — falling back to system TTS")
                try? AudioSessionManager.shared.configureForSpeaking(.speechSynthesizer)
                await fallbackTTS.speak(text)
            }
        }
        await currentTask?.value
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
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            throw OpenAITTSError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model.rawValue,
            "input": text,
            "voice": voice.rawValue
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITTSError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw OpenAITTSError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw OpenAITTSError.rateLimited
            }
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            log.error("OpenAI TTS HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
            throw OpenAITTSError.synthesizeFailed
        }

        guard !data.isEmpty else {
            throw OpenAITTSError.emptyResponse
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
            if !player.play() {
                self.playbackContinuation = nil
                continuation.resume()
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension OpenAITTS: AVAudioPlayerDelegate {
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
