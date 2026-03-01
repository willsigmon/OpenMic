import Foundation
import AVFoundation
import os.log

private let elLog = Logger(subsystem: "com.willsigmon.openmic", category: "ElevenLabsTTS")

/// ElevenLabs TTS engine with streaming audio playback.
/// Sends text to ElevenLabs API, receives audio chunks, plays them as they arrive
/// for minimal perceived latency. Falls back to system TTS on failure.
@MainActor
final class ElevenLabsTTS: NSObject, TTSEngineProtocol {
    private let apiKey: String
    private var voiceID: String
    private var modelID: ElevenLabsModel
    private var voiceSettings: ElevenLabsVoiceSettings

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    init(
        apiKey: String,
        voiceID: String = "21m00Tcm4TlvDq8ikWAM",
        model: ElevenLabsModel = .flash,
        voiceSettings: ElevenLabsVoiceSettings = .conversational
    ) {
        self.apiKey = apiKey
        self.voiceID = voiceID
        self.modelID = model
        self.voiceSettings = voiceSettings
        super.init()
    }

    // MARK: - Configuration

    func setVoice(id: String) {
        self.voiceID = id
    }

    func setModel(_ model: ElevenLabsModel) {
        self.modelID = model
    }

    func setVoiceSettings(_ settings: ElevenLabsVoiceSettings) {
        self.voiceSettings = settings
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
            elLog.error("ElevenLabs failed: \(error.localizedDescription, privacy: .public) — falling back to system TTS")
            // Fall back to system voice so the user always hears something
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

    // MARK: - Streaming Synthesis

    /// Synthesizes text to audio using ElevenLabs streaming endpoint.
    /// Returns complete audio data for playback.
    private func synthesize(text: String) async throws -> Data {
        let urlString = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/stream"

        guard let url = URL(string: urlString) else {
            throw ElevenLabsError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": modelID.rawValue,
            "voice_settings": [
                "stability": voiceSettings.stability,
                "similarity_boost": voiceSettings.similarityBoost,
                "style": voiceSettings.style,
                "use_speaker_boost": voiceSettings.useSpeakerBoost
            ],
            "optimize_streaming_latency": modelID.optimizeLatency
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Stream the response bytes for lower TTFB
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw ElevenLabsError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw ElevenLabsError.rateLimited
            }
            throw ElevenLabsError.synthesizeFailed
        }

        // Accumulate streamed audio bytes
        var audioData = Data()
        for try await byte in bytes {
            if Task.isCancelled { throw CancellationError() }
            audioData.append(byte)
        }

        guard !audioData.isEmpty else {
            throw ElevenLabsError.synthesizeFailed
        }

        return audioData
    }

    // MARK: - Audio Playback

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

extension ElevenLabsTTS: AVAudioPlayerDelegate {
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

// MARK: - ElevenLabs Models

enum ElevenLabsModel: String, CaseIterable, Codable, Sendable, Identifiable {
    case flash = "eleven_flash_v2_5"
    case turbo = "eleven_turbo_v2_5"
    case multilingualV2 = "eleven_multilingual_v2"
    case englishV1 = "eleven_monolingual_v1"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: "Flash v2.5"
        case .turbo: "Turbo v2.5"
        case .multilingualV2: "Multilingual v2"
        case .englishV1: "English v1"
        }
    }

    var subtitle: String {
        switch self {
        case .flash: "~75ms — Ultra-low latency, best for real-time"
        case .turbo: "~250ms — Balanced quality and speed"
        case .multilingualV2: "~400ms — Best quality, 29 languages"
        case .englishV1: "~300ms — English optimized"
        }
    }

    /// Latency optimization level (0-4, higher = more optimized but lower quality)
    var optimizeLatency: Int {
        switch self {
        case .flash: 4
        case .turbo: 3
        case .multilingualV2: 2
        case .englishV1: 2
        }
    }
}

// MARK: - Voice Settings Presets

struct ElevenLabsVoiceSettings: Codable, Sendable {
    var stability: Double
    var similarityBoost: Double
    var style: Double
    var useSpeakerBoost: Bool

    /// Balanced for natural conversation
    static let conversational = ElevenLabsVoiceSettings(
        stability: 0.5,
        similarityBoost: 0.75,
        style: 0.0,
        useSpeakerBoost: true
    )

    /// More expressive, less stable — good for storytelling
    static let expressive = ElevenLabsVoiceSettings(
        stability: 0.3,
        similarityBoost: 0.85,
        style: 0.4,
        useSpeakerBoost: true
    )

    /// Very stable, clear — good for instructions/directions
    static let clear = ElevenLabsVoiceSettings(
        stability: 0.8,
        similarityBoost: 0.6,
        style: 0.0,
        useSpeakerBoost: true
    )
}

// MARK: - Errors

enum ElevenLabsError: LocalizedError {
    case synthesizeFailed
    case invalidAPIKey
    case apiKeyMissing
    case rateLimited
    case voiceNotFound
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .synthesizeFailed: "ElevenLabs synthesis failed"
        case .invalidAPIKey: "Invalid ElevenLabs API key"
        case .apiKeyMissing: "ElevenLabs API key not configured"
        case .rateLimited: "ElevenLabs rate limit reached — wait a moment"
        case .voiceNotFound: "Selected voice not found"
        case .networkError(let msg): "ElevenLabs: \(msg)"
        }
    }
}
