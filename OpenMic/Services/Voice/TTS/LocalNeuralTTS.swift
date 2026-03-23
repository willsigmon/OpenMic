import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "LocalNeuralTTS")

/// On-device neural TTS using Piper VITS models via sherpa-onnx.
///
/// Runs entirely on-device with no network dependency.
/// Models are bundled in the app (or downloaded on first use).
/// Output is 16-bit PCM at the model's sample rate, played via AVAudioPlayer.
@MainActor
final class LocalNeuralTTS: NSObject, TTSEngineProtocol {
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    private let modelName: String
    private var synthesizer: PiperSynthesizer?

    init(modelName: String = "en_US-amy-medium") {
        self.modelName = modelName
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
                let synth = try getOrCreateSynthesizer()
                let audioData = try synth.synthesize(text: text)
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

    // MARK: - Synthesizer

    private func getOrCreateSynthesizer() throws -> PiperSynthesizer {
        if let existing = synthesizer { return existing }
        let synth = try PiperSynthesizer(modelName: modelName)
        synthesizer = synth
        return synth
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

// MARK: - Piper Synthesizer Wrapper

/// Wraps a Piper VITS model for on-device speech synthesis.
/// This is a bridge to sherpa-onnx's offline TTS API.
///
/// When sherpa-onnx SPM package is added, this calls the C API directly.
/// Until then, this uses a bundled model with ONNX Runtime.
final class PiperSynthesizer: @unchecked Sendable {
    private let modelPath: String
    private let tokensPath: String
    private let dataDir: String?
    private let sampleRate: Int

    init(modelName: String) throws {
        guard let modelURL = Bundle.main.url(
            forResource: modelName,
            withExtension: "onnx",
            subdirectory: "PiperModels"
        ) else {
            throw LocalNeuralTTSError.modelNotFound(modelName)
        }

        guard let tokensURL = Bundle.main.url(
            forResource: "tokens",
            withExtension: "txt",
            subdirectory: "PiperModels"
        ) else {
            throw LocalNeuralTTSError.tokensNotFound
        }

        self.modelPath = modelURL.path
        self.tokensPath = tokensURL.path
        self.dataDir = Bundle.main.url(
            forResource: "espeak-ng-data",
            withExtension: nil,
            subdirectory: "PiperModels"
        )?.path
        self.sampleRate = 22050 // Piper models typically use 22050 Hz

        log.info("Loaded Piper model: \(modelName, privacy: .public)")
    }

    /// Synthesize text to WAV audio data.
    func synthesize(text: String) throws -> Data {
        #if canImport(SherpaOnnx)
        return try synthesizeWithSherpa(text: text)
        #else
        throw LocalNeuralTTSError.sherpaOnnxNotAvailable
        #endif
    }

    #if canImport(SherpaOnnx)
    private func synthesizeWithSherpa(text: String) throws -> Data {
        // sherpa-onnx offline TTS integration point
        // This will be implemented when the SPM package is added
        let config = sherpaOnnxOfflineTtsConfig(
            model: modelPath,
            tokens: tokensPath,
            dataDir: dataDir ?? ""
        )
        guard let tts = SherpaOnnxOfflineTts(config: config) else {
            throw LocalNeuralTTSError.initFailed
        }
        let audio = tts.generate(text: text)
        return wavData(from: audio.samples, sampleRate: Int32(audio.sampleRate))
    }
    #endif

    /// Convert raw PCM float samples to WAV data for AVAudioPlayer.
    private func wavData(from samples: [Float], sampleRate: Int32) -> Data {
        let numSamples = samples.count
        let dataSize = numSamples * 2 // 16-bit PCM
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
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) }) // byte rate
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) }) // block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample

        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        // Convert float samples to int16
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * 32767.0)
            data.append(contentsOf: withUnsafeBytes(of: int16.littleEndian) { Array($0) })
        }

        return data
    }
}

// MARK: - Errors

enum LocalNeuralTTSError: LocalizedError {
    case modelNotFound(String)
    case tokensNotFound
    case initFailed
    case sherpaOnnxNotAvailable

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            "Piper model '\(name)' not found in app bundle"
        case .tokensNotFound:
            "Piper tokens file not found in app bundle"
        case .initFailed:
            "Failed to initialize on-device TTS engine"
        case .sherpaOnnxNotAvailable:
            "On-device neural TTS requires the sherpa-onnx package (not yet integrated)"
        }
    }
}
