import Foundation

enum SpeechPaceProfile: String, CaseIterable, Sendable {
    case fast
    case balanced
    case patient
}

struct SpeechEndpointingConfig: Sendable {
    let speakingStart: Float
    let speakingFloor: Float
    let minimumUtterance: TimeInterval
    let trailingSilenceToCommit: TimeInterval
    let maxUtterance: TimeInterval
    let preSpeechTimeout: TimeInterval
    let postEndFinalResultTimeout: TimeInterval
}

extension SpeechEndpointingConfig {
    static func forProfile(_ profile: SpeechPaceProfile) -> Self {
        switch profile {
        case .fast: .fast
        case .balanced: .balanced
        case .patient: .patient
        }
    }

    static let fast = Self(
        speakingStart: 0.075,
        speakingFloor: 0.03,
        minimumUtterance: 0.18,
        trailingSilenceToCommit: 0.62,
        maxUtterance: 10.0,
        preSpeechTimeout: 4.0,
        postEndFinalResultTimeout: 1.2
    )

    static let balanced = Self(
        speakingStart: 0.09,
        speakingFloor: 0.04,
        minimumUtterance: 0.25,
        trailingSilenceToCommit: 0.9,
        maxUtterance: 11.0,
        preSpeechTimeout: 4.5,
        postEndFinalResultTimeout: 1.5
    )

    static let patient = Self(
        speakingStart: 0.10,
        speakingFloor: 0.045,
        minimumUtterance: 0.3,
        trailingSilenceToCommit: 1.2,
        maxUtterance: 12.0,
        preSpeechTimeout: 5.0,
        postEndFinalResultTimeout: 1.8
    )
}
