import Foundation

// MARK: - Protocol (unconditionally available for cross-target use)

/// A type-erased interface for the Live Activity manager so ConversationViewModel
/// can reference it without coupling to ActivityKit availability at every call site.
@MainActor
protocol VoiceSessionActivityManaging: AnyObject {
    func startSession(personaName: String, providerName: String) async
    func updateState(_ voiceState: VoiceSessionState, messageCount: Int) async
    func endSession() async
}

// MARK: - No-op shim (used when ActivityKit is unavailable)

@MainActor
final class NoOpVoiceSessionActivityManager: VoiceSessionActivityManaging {
    static let shared = NoOpVoiceSessionActivityManager()
    private init() {}
    func startSession(personaName: String, providerName: String) async {}
    func updateState(_ voiceState: VoiceSessionState, messageCount: Int) async {}
    func endSession() async {}
}

#if canImport(ActivityKit) && os(iOS)

import ActivityKit
import os.log

private let logger = Logger(subsystem: "com.willsigmon.openmic", category: "VoiceSessionActivityManager")

// MARK: - Manager

/// Manages the lifecycle of the voice-session Live Activity.
///
/// Ownership model: `ConversationViewModel` holds a reference and calls
/// `startSession`, `updateState`, and `endSession` at the appropriate
/// pipeline lifecycle points.
///
/// Thread safety: `@MainActor` throughout. ActivityKit `Activity.request`,
/// `activity.update`, and `activity.end` are async and safe to call on
/// MainActor.
@available(iOS 16.1, *)
@Observable
@MainActor
final class VoiceSessionActivityManager: VoiceSessionActivityManaging {

    // MARK: - Singleton

    static let shared = VoiceSessionActivityManager()

    // MARK: - State

    /// The currently running activity, if any.
    private(set) var isActive: Bool = false
    private var activity: Activity<VoiceSessionAttributes>?
    private var sessionStart: Date?
    private var messageCount: Int = 0
    private var elapsedTask: Task<Void, Never>?

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Start a Live Activity when the voice pipeline begins.
    ///
    /// - Parameters:
    ///   - personaName: The active persona's display name.
    ///   - providerName: The active AI provider's short name.
    func startSession(personaName: String, providerName: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities not enabled — skipping session start.")
            return
        }

        // End any stale activity from a previous crash or incomplete session.
        await endSessionIfNeeded()

        let attributes = VoiceSessionAttributes(
            personaName: personaName,
            providerName: providerName
        )
        let initialState = VoiceSessionAttributes.ContentState(
            state: "idle",
            elapsedSeconds: 0,
            messageCount: 0
        )
        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            let newActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activity = newActivity
            sessionStart = Date()
            messageCount = 0
            isActive = true
            startElapsedTimer()
            Haptics.conversationStarted()
            logger.info("Live Activity started: \(newActivity.id)")
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Push a voice state update into the Live Activity.
    ///
    /// - Parameters:
    ///   - voiceState: The new `VoiceSessionState`.
    ///   - messageCount: The running total of messages in this session.
    func updateState(_ voiceState: VoiceSessionState, messageCount: Int) async {
        guard let activity else { return }
        self.messageCount = messageCount

        let stateString: String
        switch voiceState {
        case .listening: stateString = "listening"
        case .processing: stateString = "processing"
        case .speaking: stateString = "speaking"
        default: stateString = "idle"
        }

        let elapsed = sessionStart.map { Int(Date().timeIntervalSince($0)) } ?? 0
        let updatedState = VoiceSessionAttributes.ContentState(
            state: stateString,
            elapsedSeconds: elapsed,
            messageCount: messageCount
        )

        await activity.update(ActivityContent(state: updatedState, staleDate: nil))
    }

    /// End the Live Activity when the pipeline stops.
    func endSession() async {
        await endSessionIfNeeded()
    }

    // MARK: - Private

    private func startElapsedTimer() {
        elapsedTask?.cancel()
        elapsedTask = Task { [weak self] in
            // Update the elapsed counter every 5 seconds while the session is alive.
            // ActivityKit's 4 KB update budget makes frequent ticks cheap here
            // since ContentState is tiny.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, let activity = self.activity,
                      !Task.isCancelled else { break }
                let elapsed = self.sessionStart.map { Int(Date().timeIntervalSince($0)) } ?? 0
                let current = activity.content.state
                let updated = VoiceSessionAttributes.ContentState(
                    state: current.state,
                    elapsedSeconds: elapsed,
                    messageCount: self.messageCount
                )
                await activity.update(ActivityContent(state: updated, staleDate: nil))
            }
        }
    }

    private func endSessionIfNeeded() async {
        elapsedTask?.cancel()
        elapsedTask = nil
        guard let activity else { return }

        let finalState = VoiceSessionAttributes.ContentState(
            state: "idle",
            elapsedSeconds: sessionStart.map { Int(Date().timeIntervalSince($0)) } ?? 0,
            messageCount: messageCount
        )
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .default
        )
        self.activity = nil
        sessionStart = nil
        isActive = false
        Haptics.conversationEnded()
        logger.info("Live Activity ended.")
    }
}

#endif // canImport(ActivityKit) && os(iOS)
