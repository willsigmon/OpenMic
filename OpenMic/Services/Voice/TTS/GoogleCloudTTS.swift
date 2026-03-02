import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "GoogleCloudTTS")

/// Google Cloud Text-to-Speech engine with 300+ voices across Standard/WaveNet/Neural2/Studio tiers.
/// Falls back to SystemTTS on failure.
@MainActor
final class GoogleCloudTTS: NSObject, TTSEngineProtocol {
    private let apiKey: String
    private var voiceId: String

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    init(apiKey: String, voiceId: String = "en-US-Neural2-A") {
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
                log.error("Google Cloud TTS failed: \(error.localizedDescription, privacy: .public) — falling back to system TTS")
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
        guard let url = URL(string: "https://texttospeech.googleapis.com/v1/text:synthesize") else {
            throw GoogleCloudTTSError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        let body: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": voiceId.components(separatedBy: "-").prefix(2).joined(separator: "-"),
                "name": voiceId
            ],
            "audioConfig": [
                "audioEncoding": "MP3"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCloudTTSError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw GoogleCloudTTSError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw GoogleCloudTTSError.rateLimited
            }
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            log.error("Google Cloud TTS HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
            throw GoogleCloudTTSError.synthesizeFailed
        }

        // Response contains base64-encoded audio in "audioContent" field
        struct SynthesizeResponse: Decodable {
            let audioContent: String
        }

        let decoded = try JSONDecoder().decode(SynthesizeResponse.self, from: data)

        guard let audioData = Data(base64Encoded: decoded.audioContent), !audioData.isEmpty else {
            throw GoogleCloudTTSError.emptyResponse
        }

        return audioData
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

extension GoogleCloudTTS: AVAudioPlayerDelegate {
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
