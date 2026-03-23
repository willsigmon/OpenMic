import AVFoundation
import os.log

#if canImport(KokoroSwift)
import KokoroSwift
import MLX
#endif

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "LocalNeuralTTS")

/// On-device neural TTS using Kokoro (82M) via MLX Swift.
///
/// Runs entirely on-device with no network dependency.
/// Uses Apple's MLX framework for Neural Engine / GPU acceleration.
/// Output is PCM audio played via AVAudioPlayer.
@MainActor
final class LocalNeuralTTS: NSObject, TTSEngineProtocol {
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    #if canImport(KokoroSwift)
    private var tts: KokoroTTS?
    private var voiceEmbedding: MLXArray?
    #endif

    override init() {
        super.init()
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
                log.error("Local neural TTS failed: \(error.localizedDescription, privacy: .public) — falling back to system")
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
        #if canImport(KokoroSwift)
        return try synthesizeWithKokoro(text: text)
        #else
        throw LocalNeuralTTSError.kokoroNotAvailable
        #endif
    }

    #if canImport(KokoroSwift)
    private func synthesizeWithKokoro(text: String) throws -> Data {
        let engine = try getOrCreateEngine()
        let voice = try getOrLoadVoice()

        let (samples, _) = try engine.generateAudio(
            voice: voice,
            language: .enUS,
            text: text,
            speed: 1.0
        )
        return wavData(from: samples, sampleRate: 24000)
    }

    private func getOrCreateEngine() throws -> KokoroTTS {
        if let existing = tts { return existing }

        guard let modelURL = Bundle.main.url(
            forResource: "kokoro-v1",
            withExtension: nil,
            subdirectory: "KokoroModel"
        ) else {
            throw LocalNeuralTTSError.modelNotFound
        }

        let engine = KokoroTTS(modelPath: modelURL, g2p: .misaki)
        tts = engine
        log.info("Kokoro TTS engine initialized")
        return engine
    }

    private func getOrLoadVoice() throws -> MLXArray {
        if let existing = voiceEmbedding { return existing }

        guard let voicesURL = Bundle.main.url(
            forResource: "voices",
            withExtension: "bin",
            subdirectory: "KokoroModel"
        ) else {
            throw LocalNeuralTTSError.voiceNotFound
        }

        // Load voice pack and extract first voice (af_heart — warm female)
        let data = try Data(contentsOf: voicesURL)
        let voice = try MLX.loadArrays(url: voicesURL).first?.value
            ?? { throw LocalNeuralTTSError.voiceNotFound }()

        voiceEmbedding = voice
        log.info("Loaded Kokoro voice embedding")
        return voice
    }
    #endif

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

    // MARK: - WAV Encoding

    private func wavData(from samples: [Float], sampleRate: Int32) -> Data {
        let numSamples = samples.count
        let dataSize = numSamples * 2
        let fileSize = 44 + dataSize

        var data = Data(capacity: fileSize)

        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize - 8).littleEndian) { Array($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // mono
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) }) // block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits/sample

        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * 32767.0)
            data.append(contentsOf: withUnsafeBytes(of: int16.littleEndian) { Array($0) })
        }

        return data
    }
}

// MARK: - AVAudioPlayerDelegate

extension LocalNeuralTTS: AVAudioPlayerDelegate {
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

// MARK: - Errors

enum LocalNeuralTTSError: LocalizedError {
    case modelNotFound
    case voiceNotFound
    case initFailed
    case kokoroNotAvailable

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            "Kokoro model not found in app bundle. Add KokoroModel/ directory with model weights."
        case .voiceNotFound:
            "Kokoro voice embedding not found. Add voices.bin to KokoroModel/ directory."
        case .initFailed:
            "Failed to initialize on-device Kokoro TTS engine"
        case .kokoroNotAvailable:
            "On-device neural TTS requires the KokoroSwift package"
        }
    }
}
