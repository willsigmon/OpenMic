import Foundation
import AVFoundation
import os.log

/// Shared base class for all cloud-backed TTS engines that receive audio data
/// and play it through AVAudioPlayer.
///
/// Subclasses must implement `synthesize(text:)` to call their respective API
/// and return raw audio bytes. Everything else — task management, playback,
/// cancellation, and SystemTTS fallback — is handled here.
@MainActor
class CloudTTSBase: NSObject, TTSEngineProtocol {
    // Subclasses set this in their initializer via `super.init(log:)`.
    let engineLog: Logger

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private lazy var fallbackTTS = SystemTTS()

    private(set) var isSpeaking = false
    let audioRequirement: TTSAudioRequirement = .audioPlayer

    init(log: Logger) {
        self.engineLog = log
        super.init()
    }

    // MARK: - Abstract

    /// Subclasses implement this to call their API and return audio data.
    func synthesize(text: String) async throws -> Data {
        preconditionFailure("Subclasses must override synthesize(text:)")
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
                engineLog.error(
                    "TTS failed: \(error.localizedDescription, privacy: .public) — falling back to system TTS"
                )
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

    // MARK: - Playback

    func playAudio(data: Data) async throws {
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

extension CloudTTSBase: AVAudioPlayerDelegate {
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
