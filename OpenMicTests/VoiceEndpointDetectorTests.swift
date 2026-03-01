import Testing
import Foundation
@testable import OpenMic

@Suite("Voice Endpoint Detector")
struct VoiceEndpointDetectorTests {
    @Test("Ends utterance after trailing silence in fast profile")
    func endsAfterTrailingSilence() {
        var detector = VoiceEndpointDetector(config: .fast)
        let actions = feed(
            detector: &detector,
            samples:
                repeated(level: 0.35, count: 4, step: 0.1) +
                repeated(level: 0.0, count: 8, step: 0.1)
        )

        #expect(actions.contains(.endAudio))
        #expect(actions.filter { $0 == .endAudio }.count == 1)
    }

    @Test("Does not end before minimum utterance")
    func doesNotEndBeforeMinimumUtterance() {
        var detector = VoiceEndpointDetector(config: .fast)
        let actions = feed(
            detector: &detector,
            samples:
                repeated(level: 0.35, count: 3, step: 0.05) +
                repeated(level: 0.0, count: 10, step: 0.05)
        )

        #expect(actions.allSatisfy { $0 == .continueListening })
    }

    @Test("Ignores pre-speech low-level noise")
    func ignoresPreSpeechNoise() {
        var detector = VoiceEndpointDetector(config: .fast)
        let actions = feed(
            detector: &detector,
            samples:
                repeated(level: 0.05, count: 35, step: 0.1) +
                repeated(level: 0.3, count: 3, step: 0.1) +
                repeated(level: 0.0, count: 7, step: 0.1)
        )

        #expect(actions[..<35].allSatisfy { $0 == .continueListening })
        #expect(actions.contains(.endAudio))
    }

    @Test("Allows brief pause inside utterance without committing")
    func allowsBriefPauseInsideUtterance() {
        var detector = VoiceEndpointDetector(config: .fast)
        let actions = feed(
            detector: &detector,
            samples:
                repeated(level: 0.3, count: 3, step: 0.1) +
                repeated(level: 0.0, count: 3, step: 0.1) + // short pause
                repeated(level: 0.3, count: 3, step: 0.1) +
                repeated(level: 0.0, count: 7, step: 0.1) // final pause
        )

        #expect(actions[..<9].allSatisfy { $0 == .continueListening })
        #expect(actions.contains(.endAudio))
    }

    @Test("Ends at max utterance safety cutoff")
    func endsAtMaxUtteranceCutoff() {
        var detector = VoiceEndpointDetector(config: .fast)
        let actions = feed(
            detector: &detector,
            samples: repeated(level: 0.3, count: 101, step: 0.1)
        )

        #expect(actions.contains(.endAudio))
        #expect(actions.filter { $0 == .endAudio }.count == 1)
    }

    @Test("Handles immediate silence after speech start")
    func handlesImmediateSilenceAfterSpeechStart() {
        var detector = VoiceEndpointDetector(config: .fast)
        let actions = feed(
            detector: &detector,
            samples:
                repeated(level: 0.4, count: 2, step: 0.1) +
                repeated(level: 0.0, count: 7, step: 0.1)
        )

        #expect(actions.contains(.endAudio))
    }

    @Test("Emits no duplicate end action")
    func emitsNoDuplicateEndAction() {
        var detector = VoiceEndpointDetector(config: .fast)
        let actions = feed(
            detector: &detector,
            samples:
                repeated(level: 0.35, count: 4, step: 0.1) +
                repeated(level: 0.0, count: 8, step: 0.1) +
                repeated(level: 0.35, count: 20, step: 0.1)
        )

        #expect(actions.filter { $0 == .endAudio }.count == 1)
        #expect(detector.hasEnded == true)
    }
}

private func repeated(
    level: Float,
    count: Int,
    step: TimeInterval
) -> [(level: Float, duration: TimeInterval)] {
    Array(repeating: (level: level, duration: step), count: count)
}

private func feed(
    detector: inout VoiceEndpointDetector,
    samples: [(level: Float, duration: TimeInterval)]
) -> [VoiceEndpointAction] {
    samples.map { sample in
        detector.ingest(
            normalizedLevel: sample.level,
            duration: sample.duration
        )
    }
}
