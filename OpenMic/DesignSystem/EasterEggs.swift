//
//  EasterEggs.swift
//  OpenMic
//
//  Hidden interaction delights. Techy, playful, rewarding curiosity.
//  Port of Modcaster's BlackboxDelight patterns, tuned for OpenMic's
//  voice-first Midnight Dashboard personality.
//

import SwiftUI
import UIKit

// MARK: - Triple Tap: Secret Agent Mode

/// Detects three taps within 0.4s and fires an action.
/// Matches the TripleTapGesture timing from Modcaster's BlackboxDelight.
struct TripleTapGesture: ViewModifier {
    let action: () -> Void

    @State private var tapCount = 0
    @State private var lastTapTime = Date.distantPast

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                let now = Date()
                if now.timeIntervalSince(lastTapTime) < 0.4 {
                    tapCount += 1
                } else {
                    tapCount = 1
                }
                lastTapTime = now

                if tapCount >= 3 {
                    Haptics.celebrationPattern()
                    action()
                    tapCount = 0
                }
            }
    }
}

extension View {
    func onTripleTap(perform action: @escaping () -> Void) -> some View {
        modifier(TripleTapGesture(action: action))
    }
}

// MARK: - Secret Agent Mode Badge

/// Visual indicator that appears when Secret Agent Mode is activated via triple-tap.
/// Shown overlaid on the mic button — does not change TTS behavior.
struct SecretAgentBadgeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var iconPhase: Bool = false

    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                .symbolEffect(.bounce, value: iconPhase)

            Text("Secret Agent Mode")
                .font(OpenMicTheme.Typography.callout)
                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
        }
        .padding(.horizontal, OpenMicTheme.Spacing.md)
        .padding(.vertical, OpenMicTheme.Spacing.xs)
        .background(.ultraThickMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    OpenMicTheme.Colors.accentGradientStart.opacity(0.4),
                    lineWidth: 1
                )
        )
        .shadow(color: OpenMicTheme.Colors.glowCyan, radius: 12)
        .scaleEffect(appeared ? 1 : 0.7)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                appeared = true
            }
            // Bounce the icon on appear
            iconPhase = true
        }
    }
}

// MARK: - Secret Agent Mode Modifier

/// Applies Secret Agent Mode easter egg to the mic button.
/// Triple-tap while NOT in an active voice session to activate.
/// Shows a visual badge for 2.5 seconds and fires a heavy celebration haptic.
struct SecretAgentModeModifier: ViewModifier {
    let isSessionActive: Bool

    @State private var showBadge = false

    func body(content: Content) -> some View {
        content
            .onTripleTap {
                guard !isSessionActive else { return }
                showBadge = true

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(2500))
                    withAnimation(.easeOut(duration: 0.3)) {
                        showBadge = false
                    }
                }
            }
            .overlay(alignment: .top) {
                if showBadge {
                    SecretAgentBadgeView()
                        .transition(.scale.combined(with: .opacity))
                        .offset(y: -56)
                }
            }
            .animation(
                .spring(response: 0.4, dampingFraction: 0.7),
                value: showBadge
            )
    }
}

extension View {
    /// Adds Secret Agent Mode easter egg to the mic button.
    /// Triple-tap while not in a session to trigger.
    func secretAgentMode(isSessionActive: Bool) -> some View {
        modifier(SecretAgentModeModifier(isSessionActive: isSessionActive))
    }
}

// MARK: - Shake Detection (UIKit bridge)

private final class ShakeDetectingViewController: UIViewController {
    var onShake: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
    }
}

private struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectingViewController {
        let vc = ShakeDetectingViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(
        _ uiViewController: ShakeDetectingViewController,
        context: Context
    ) {
        uiViewController.onShake = onShake
    }
}

// MARK: - Shake to Random Prompt

/// View modifier for the Talk tab: shake the device to auto-fill a random
/// prompt from `PromptSuggestions.current()`. Integrates with the existing
/// `initialPrompt` binding on `ConversationView`.
struct ShakeToRandomPromptModifier: ViewModifier {
    let isEnabled: Bool
    /// Binding writes back into ConversationView's `initialPrompt` binding.
    @Binding var pendingPrompt: String?

    @State private var showShakeIndicator = false

    func body(content: Content) -> some View {
        content
            .background {
                if isEnabled {
                    ShakeDetector {
                        Haptics.thud()
                        showShakeIndicator = true

                        let random = PromptSuggestions.current(count: 12).randomElement()
                        pendingPrompt = random?.text

                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(1500))
                            withAnimation(.easeOut(duration: 0.25)) {
                                showShakeIndicator = false
                            }
                        }
                    }
                }
            }
            .overlay {
                if showShakeIndicator {
                    ShakePromptIndicatorView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(
                .spring(response: 0.4, dampingFraction: 0.7),
                value: showShakeIndicator
            )
    }
}

extension View {
    /// Enables shake-to-random-prompt on the Talk tab.
    func shakeToRandomPrompt(
        isEnabled: Bool = true,
        pendingPrompt: Binding<String?>
    ) -> some View {
        modifier(ShakeToRandomPromptModifier(
            isEnabled: isEnabled,
            pendingPrompt: pendingPrompt
        ))
    }
}

// MARK: - Shake Indicator

private struct ShakePromptIndicatorView: View {
    @State private var iconPhase: Bool = false

    var body: some View {
        VStack(spacing: OpenMicTheme.Spacing.sm) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            OpenMicTheme.Colors.accentGradientStart,
                            OpenMicTheme.Colors.accentGradientEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: iconPhase)

            Text("Random prompt loaded")
                .font(OpenMicTheme.Typography.headline)
                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
        }
        .padding(OpenMicTheme.Spacing.xxxl)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: OpenMicTheme.Radius.xl))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .onAppear { iconPhase = true }
    }
}

// MARK: - Interactive Empty State (History Tab)

/// Escalating reactions when the user taps the empty conversation list icon.
/// Personality matches Modcaster's InteractiveEmptyStateModifier but with
/// OpenMic's voice-and-AI tone.
struct OpenMicInteractiveEmptyStateModifier: ViewModifier {
    @State private var tapCount = 0
    @State private var rotation = 0.0
    @State private var scale = 1.0
    @State private var showMessage = false
    @State private var currentMessage = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Escalating messages. Index 0 is shown at tap 3, index 1 at tap 5,
    // then index 2+ cycle for every 3 taps after that.
    private static let messages: [String] = [
        "Looking for something? Start a conversation!",
        "Persistent! I like that.",
        "The mic is always listening...",
        "Have you tried talking to yourself?",
        "Every great AI conversation starts with 'hello'.",
        "I'm starting to think you enjoy empty states.",
        "Achievement unlocked: Tapped Nothing 7+ times.",
    ]

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 120, height: 120)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleTap()
                    }
            }
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .overlay(alignment: .bottom) {
                if showMessage {
                    Text(currentMessage)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .padding(.horizontal, OpenMicTheme.Spacing.sm)
                        .padding(.vertical, OpenMicTheme.Spacing.xxs)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(
                            .scale
                                .combined(with: .opacity)
                                .combined(with: .move(edge: .top))
                        )
                        .offset(y: 64)
                }
            }
    }

    private func handleTap() {
        tapCount += 1

        switch tapCount {
        case 1...2:
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.2
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                scale = 1.0
            }
            Haptics.tap()

        case 3...4:
            guard !reduceMotion else {
                Haptics.impact()
                return
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { rotation = 15 }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3).delay(0.1)) { rotation = -15 }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3).delay(0.2)) { rotation = 0 }
            Haptics.impact()

        case 5:
            fireMessage(at: 0)
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { scale = 1.3 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.15)) { scale = 1.0 }
            Haptics.success()

        default:
            if tapCount % 2 == 0 {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    rotation += 360
                    scale = 1.1
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.2)) {
                    scale = 1.0
                }
            }

            if tapCount % 3 == 0 {
                let messageIndex = min(
                    1 + (tapCount - 5) / 3,
                    Self.messages.count - 1
                )
                fireMessage(at: messageIndex)
            }
            Haptics.impact()
        }
    }

    private func fireMessage(at index: Int) {
        let safeIndex = min(max(0, index), Self.messages.count - 1)
        currentMessage = Self.messages[safeIndex]
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            showMessage = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2200))
            withAnimation(.easeOut(duration: 0.25)) {
                showMessage = false
            }
        }
    }
}

extension View {
    /// Applies escalating-tap easter egg to an empty conversation list icon.
    func openMicInteractiveEmptyState() -> some View {
        modifier(OpenMicInteractiveEmptyStateModifier())
    }
}

// MARK: - Previews

#Preview("Secret Agent Badge") {
    ZStack {
        OpenMicTheme.Colors.background.ignoresSafeArea()
        SecretAgentBadgeView()
    }
}

#Preview("Shake Indicator") {
    ZStack {
        OpenMicTheme.Colors.background.ignoresSafeArea()
        ShakePromptIndicatorView()
    }
}

#Preview("Interactive Empty State") {
    ZStack {
        OpenMicTheme.Colors.background.ignoresSafeArea()
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
                .openMicInteractiveEmptyState()

            Text("No conversations yet")
                .font(OpenMicTheme.Typography.title)
                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

            Text("Tap the mic to start talking")
                .font(OpenMicTheme.Typography.body)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
        }
    }
}
