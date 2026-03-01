import Foundation

enum VoiceEndpointAction: Equatable, Sendable {
    case continueListening
    case endAudio
}

struct VoiceEndpointDetector: Sendable {
    private let config: SpeechEndpointingConfig

    private(set) var hasDetectedSpeech = false
    private(set) var hasEnded = false
    private(set) var totalDuration: TimeInterval = 0
    private(set) var utteranceDuration: TimeInterval = 0
    private(set) var trailingSilenceDuration: TimeInterval = 0

    init(config: SpeechEndpointingConfig) {
        self.config = config
    }

    mutating func ingest(
        normalizedLevel: Float,
        duration: TimeInterval
    ) -> VoiceEndpointAction {
        guard duration > 0 else { return .continueListening }
        guard !hasEnded else { return .continueListening }

        totalDuration += duration
        let level = max(0, min(1, normalizedLevel))
        let threshold = hasDetectedSpeech ? config.speakingFloor : config.speakingStart

        if level >= threshold {
            hasDetectedSpeech = true
            utteranceDuration += duration
            trailingSilenceDuration = 0

            if utteranceDuration >= config.maxUtterance {
                return markEnded()
            }

            return .continueListening
        }

        if hasDetectedSpeech {
            trailingSilenceDuration += duration

            if utteranceDuration >= config.minimumUtterance,
               trailingSilenceDuration >= config.trailingSilenceToCommit {
                return markEnded()
            }

            if utteranceDuration < config.minimumUtterance,
               trailingSilenceDuration >= config.preSpeechTimeout {
                return markEnded()
            }

            if utteranceDuration >= config.maxUtterance {
                return markEnded()
            }

            return .continueListening
        }

        if totalDuration >= config.preSpeechTimeout {
            return markEnded()
        }

        return .continueListening
    }

    private mutating func markEnded() -> VoiceEndpointAction {
        hasEnded = true
        return .endAudio
    }
}
