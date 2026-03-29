import UIKit
import AudioToolbox
import CoreHaptics
import SwiftUI

/// Centralized haptic feedback patterns for OpenMic.
/// Gives every interaction a tactile signature.
/// CHHapticEngine handles complex voice-state patterns; UIKit generators serve as fallbacks.
@MainActor
enum Haptics {
    @AppStorage("soundEffects") private static var soundEnabled = true
    @AppStorage("hapticsEnabled") private static var hapticsEnabled = true

    // MARK: - UIKit Generators (fallbacks)

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - CHHapticEngine

    private static var hapticEngine: CHHapticEngine?
    private static var lastHapticTime: CFTimeInterval = 0
    private static let minimumHapticInterval: CFTimeInterval = 0.1

    // MARK: - Engine Lifecycle

    /// Call once from app startup (e.g. AppServices or scene delegate).
    static func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        guard hapticEngine == nil else { return }

        do {
            let engine = try CHHapticEngine()

            engine.stoppedHandler = { reason in
                Task { @MainActor in
                    hapticEngine = nil
                }
            }

            engine.resetHandler = {
                Task { @MainActor in
                    restartEngine()
                }
            }

            try engine.start()
            hapticEngine = engine
        } catch {
            hapticEngine = nil
        }
    }

    static func stopEngine() {
        hapticEngine?.stop()
        hapticEngine = nil
    }

    private static func restartEngine() {
        hapticEngine?.stop()
        hapticEngine = nil
        startEngine()
    }

    // MARK: - Gate

    private static func canPlayHaptic(essential: Bool = false) -> Bool {
        guard hapticsEnabled else { return false }
        guard !UIAccessibility.isReduceMotionEnabled else { return false }

        // Battery gate: skip non-essential haptics below 15%
        if !essential {
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = UIDevice.current.batteryLevel
            if level >= 0 && level < 0.15 { return false }
        }

        return true
    }

    private static func isRateLimited() -> Bool {
        let now = CACurrentMediaTime()
        guard now - lastHapticTime >= minimumHapticInterval else { return true }
        lastHapticTime = now
        return false
    }

    // MARK: - CHHapticEngine Pattern Playback

    /// Play a CHHapticPattern. Falls through to UIKit fallback closure on failure.
    private static func play(
        _ patternBuilder: () throws -> CHHapticPattern,
        fallback: () -> Void
    ) {
        guard canPlayHaptic(), !isRateLimited() else { return }

        guard let engine = hapticEngine else {
            fallback()
            return
        }

        do {
            let pattern = try patternBuilder()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }

    // MARK: - Voice State Patterns (CHHapticEngine)

    /// Continuous haptic ramping intensity 0.3 → 0.6 over 1s. Represents entering listening state.
    static func listeningPattern() {
        play({
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0,
                duration: 1.0
            )
            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0.3),
                    CHHapticParameterCurve.ControlPoint(relativeTime: 1.0, value: 0.6)
                ],
                relativeTime: 0
            )
            return try CHHapticPattern(events: [event], parameterCurves: [curve])
        }, fallback: {
            rigid.impactOccurred(intensity: 0.7)
        })
    }

    /// Gentle rhythmic pulse every 0.5s at 0.3 intensity. Thinking / processing feel.
    static func processingPattern() {
        play({
            let times: [TimeInterval] = [0, 0.5, 1.0, 1.5]
            let events = times.map { t in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: t
                )
            }
            return try CHHapticPattern(events: events, parameters: [])
        }, fallback: {
            light.impactOccurred(intensity: 0.3)
        })
    }

    /// Subtle low-frequency continuous haptic at 0.2 intensity. Voice resonance feel.
    static func speakingPattern() {
        play({
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.05)
                ],
                relativeTime: 0,
                duration: 1.5
            )
            return try CHHapticPattern(events: [event], parameters: [])
        }, fallback: {
            medium.impactOccurred(intensity: 0.5)
        })
    }

    /// 5-hit descending transient pattern for conversation milestones.
    static func celebrationPattern() {
        play({
            let intensities: [Float] = [0.9, 0.75, 0.6, 0.45, 0.3]
            let times: [TimeInterval] = [0, 0.1, 0.2, 0.32, 0.46]
            let events = zip(intensities, times).map { intensity, t in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: t
                )
            }
            return try CHHapticPattern(events: events, parameters: [])
        }, fallback: {
            notification.notificationOccurred(.success)
        })
    }

    // MARK: - Basic Patterns

    /// Subtle tap — card presses, toggles, minor interactions
    static func tap() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        light.impactOccurred(intensity: 0.5)
    }

    /// Selection tick — picker changes, option selection
    static func select() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        selection.selectionChanged()
    }

    /// Medium impact — button presses, significant actions
    static func impact() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        medium.impactOccurred()
    }

    /// Heavy thud — destructive actions, important confirmations
    static func thud() {
        guard canPlayHaptic(essential: true), !isRateLimited() else { return }
        heavy.impactOccurred(intensity: 0.8)
    }

    /// Success — task completion, save confirmed
    static func success() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        notification.notificationOccurred(.success)
    }

    /// Warning — approaching limits, caution
    static func warning() {
        guard canPlayHaptic(essential: true), !isRateLimited() else { return }
        notification.notificationOccurred(.warning)
    }

    /// Error — failures, invalid actions
    static func error() {
        guard canPlayHaptic(essential: true), !isRateLimited() else { return }
        notification.notificationOccurred(.error)
    }

    // MARK: - Voice State Dispatch

    /// Plays the appropriate pattern for each voice state transition.
    /// CHHapticEngine patterns are preferred; UIKit generators are the fallback.
    static func voiceStateChanged(to state: VoiceSessionState) {
        switch state {
        case .idle:
            guard canPlayHaptic(), !isRateLimited() else { return }
            soft.impactOccurred(intensity: 0.4)
        case .listening:
            listeningPattern()
        case .processing:
            processingPattern()
        case .speaking:
            speakingPattern()
        case .error:
            guard canPlayHaptic(essential: true), !isRateLimited() else { return }
            notification.notificationOccurred(.error)
        }
    }

    // MARK: - Navigation

    /// Tab switch — crisp selection
    static func tabSwitch() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        rigid.impactOccurred(intensity: 0.4)
    }

    /// Navigate deeper — subtle forward motion
    static func navigate() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        light.impactOccurred(intensity: 0.35)
    }

    // MARK: - Conversation

    /// New message received — gentle arrival
    static func messageReceived() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        soft.impactOccurred(intensity: 0.5)
    }

    /// Conversation started — satisfying confirmation
    static func conversationStarted() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        medium.impactOccurred(intensity: 0.6)
    }

    /// Conversation ended — gentle close
    static func conversationEnded() {
        guard canPlayHaptic(), !isRateLimited() else { return }
        soft.impactOccurred(intensity: 0.3)
    }

    // MARK: - Sound Companions

    private static func playSound(_ soundID: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    /// Listening start — crisp begin-recording sound
    static func listeningStartSound() {
        listeningPattern()
        playSound(1306)
    }

    /// Speaking start — gentle tink
    static func speakingStartSound() {
        speakingPattern()
        playSound(1054)
    }

    /// Error with sound — audible error feedback
    static func errorSound() {
        guard canPlayHaptic(essential: true), !isRateLimited() else { return }
        notification.notificationOccurred(.error)
        playSound(1053)
    }
}
