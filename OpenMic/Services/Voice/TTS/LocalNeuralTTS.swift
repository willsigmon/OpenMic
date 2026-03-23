import AVFoundation
import os.log

#if canImport(FluidAudio)
@preconcurrency import FluidAudio
#endif

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "LocalNeuralTTS")

/// On-device neural TTS using Kokoro 82M via FluidAudio (CoreML).
///
/// Runs entirely on-device with no network dependency after initial model download.
/// Uses Apple's CoreML framework for Neural Engine / GPU acceleration.
/// Models auto-download from HuggingFace on first use (~200MB).
@MainActor
final class LocalNeuralTTS: NSObject, TTSEngineProtocol {
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    #if canImport(FluidAudio)
    private var ttsManager: KokoroTtsManager?
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
        #if canImport(FluidAudio)
        return try await synthesizeWithFluidAudio(text: text)
        #else
        throw LocalNeuralTTSError.fluidAudioNotAvailable
        #endif
    }

    #if canImport(FluidAudio)
    private func synthesizeWithFluidAudio(text: String) async throws -> Data {
        if ttsManager == nil || ttsManager?.isAvailable != true {
            let manager = KokoroTtsManager(defaultVoice: "af_heart")
            try await manager.initialize()
            ttsManager = manager
            log.info("FluidAudio Kokoro TTS initialized (CoreML, 24kHz)")
        }
        guard let tts = ttsManager else { throw LocalNeuralTTSError.initFailed }
        return try await tts.synthesize(text: text)
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
    case initFailed
    case fluidAudioNotAvailable

    var errorDescription: String? {
        switch self {
        case .initFailed:
            "Failed to initialize on-device Kokoro TTS engine"
        case .fluidAudioNotAvailable:
            "On-device neural TTS requires the FluidAudio package"
        }
    }
}
