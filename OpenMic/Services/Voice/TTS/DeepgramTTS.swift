import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "DeepgramTTS")

/// Deepgram Aura TTS engine — fast, simple REST API.
/// Falls back to SystemTTS on failure.
@MainActor
final class DeepgramTTS: NSObject, TTSEngineProtocol {
    private let apiKey: String
    private var voiceId: String

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    init(apiKey: String, voiceId: String = "aura-2-theia-en") {
        self.apiKey = apiKey
        self.voiceId = voiceId
        super.init()
    }

    // MARK: - Configuration

    func setVoice(id: String) {
        self.voiceId = id
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
                log.error("Deepgram TTS failed: \(error.localizedDescription, privacy: .public) — falling back to system TTS")
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
        var components = URLComponents(string: "https://api.deepgram.com/v1/speak")!
        components.queryItems = [URLQueryItem(name: "model", value: voiceId)]
        guard let url = components.url else {
            throw DeepgramTTSError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepgramTTSError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw DeepgramTTSError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw DeepgramTTSError.rateLimited
            }
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            log.error("Deepgram TTS HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
            throw DeepgramTTSError.synthesizeFailed
        }

        guard !data.isEmpty else {
            throw DeepgramTTSError.emptyResponse
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

extension DeepgramTTS: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }
}
