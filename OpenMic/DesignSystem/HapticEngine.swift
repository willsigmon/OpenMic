import UIKit
import AudioToolbox
import SwiftUI

/// Centralized haptic feedback patterns for OpenMic.
/// Gives every interaction a tactile signature.
@MainActor
enum Haptics {
    @AppStorage("soundEffects") private static var soundEnabled = true
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Basic Patterns

    /// Subtle tap — card presses, toggles, minor interactions
    static func tap() {
        light.impactOccurred(intensity: 0.5)
    }

    /// Selection tick — picker changes, option selection
    static func select() {
        selection.selectionChanged()
    }

    /// Medium impact — button presses, significant actions
    static func impact() {
        medium.impactOccurred()
    }

    /// Heavy thud — destructive actions, important confirmations
    static func thud() {
        heavy.impactOccurred(intensity: 0.8)
    }

    /// Success — task completion, save confirmed
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// Warning — approaching limits, caution
    static func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Error — failures, invalid actions
    static func error() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Voice State Patterns

    /// Distinct haptic signature per voice state transition
    static func voiceStateChanged(to state: VoiceSessionState) {
        switch state {
        case .idle:
            // Gentle wind-down — soft landing
            soft.impactOccurred(intensity: 0.4)
        case .listening:
            // Crisp activation — "I'm here"
            rigid.impactOccurred(intensity: 0.7)
        case .processing:
            // Subtle pulse — thinking tick
            light.impactOccurred(intensity: 0.3)
        case .speaking:
            // Warm medium — response arriving
            medium.impactOccurred(intensity: 0.5)
        case .error:
            notification.notificationOccurred(.error)
        }
    }

    // MARK: - Navigation

    /// Tab switch — crisp selection
    static func tabSwitch() {
        rigid.impactOccurred(intensity: 0.4)
    }

    /// Navigate deeper — subtle forward motion
    static func navigate() {
        light.impactOccurred(intensity: 0.35)
    }

    // MARK: - Conversation

    /// New message received — gentle arrival
    static func messageReceived() {
        soft.impactOccurred(intensity: 0.5)
    }

    /// Conversation started — satisfying confirmation
    static func conversationStarted() {
        medium.impactOccurred(intensity: 0.6)
    }

    /// Conversation ended — gentle close
    static func conversationEnded() {
        soft.impactOccurred(intensity: 0.3)
    }

    // MARK: - Sound Companions

    /// Play a subtle system sound alongside haptic feedback
    private static func playSound(_ soundID: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    /// Listening start — crisp begin-recording sound
    static func listeningStartSound() {
        rigid.impactOccurred(intensity: 0.7)
        playSound(1306)
    }

    /// Speaking start — gentle tink
    static func speakingStartSound() {
        medium.impactOccurred(intensity: 0.5)
        playSound(1054)
    }

    /// Error with sound — audible error feedback
    static func errorSound() {
        notification.notificationOccurred(.error)
        playSound(1053)
    }
}
