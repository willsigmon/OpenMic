import SwiftUI

// MARK: - ConversationCelebrationStyle

/// Voice-AI-domain celebration styles for OpenMic.
/// Particle shapes and palettes are calibrated for the Midnight Dashboard aesthetic:
/// deep blacks, electric accents, no warm confetti colours.
enum ConversationCelebrationStyle: Hashable, Sendable {
    /// Colourful confetti burst — conversation milestone (10th, 50th, 100th message)
    case confetti
    /// Electric-cyan four-point stars — first message in a new conversation
    case sparkles
    /// Sine-wave arcs — AI insight or reasoning moment
    case brainWaves
}

// MARK: - ConversationCelebrationContext

/// Semantic events mapped to a style. One source of truth for call sites.
enum ConversationCelebrationContext: Hashable, Sendable {
    case conversationMilestone(Int)   // message count: 10, 50, 100
    case firstMessage
    case aiInsight
}

extension ConversationCelebrationContext {
    var style: ConversationCelebrationStyle {
        switch self {
        case .conversationMilestone:   return .confetti
        case .firstMessage:            return .sparkles
        case .aiInsight:               return .brainWaves
        }
    }

    /// Particle count scaled to the significance of the event.
    var particleCount: Int {
        switch self {
        case .conversationMilestone(let n):
            if n >= 100 { return CelebrationSize.large }
            if n >= 50  { return 35 }
            return CelebrationSize.small          // 10th message
        case .firstMessage:  return CelebrationSize.small
        case .aiInsight:     return 18
        }
    }
}

// MARK: - BrainWaveShape

/// A single cycle of a sine wave rendered as a stroked `Path`.
/// Represents an AI "thinking" or insight moment — unique to OpenMic.
struct BrainWaveShape: Shape {
    /// Number of full sine cycles across the bounding rect width.
    let cycles: Int

    init(cycles: Int = 2) {
        self.cycles = cycles
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            let steps = 80
            let width = rect.width
            let midY = rect.midY
            let amplitude = rect.height * 0.42

            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let x = rect.minX + t * width
                let angle = t * .pi * 2 * CGFloat(cycles)
                let y = midY + sin(angle) * amplitude

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

// MARK: - MilestoneCelebrationView

/// Layered view that combines the existing `CelebrationParticleView` (background particles)
/// with the keyframe card animation (foreground element).
///
/// The Wave 1 milestone detection in `ConversationView` drives the card animation
/// and particle burst from a single trigger increment, keeping state in one place.
///
/// Usage:
/// ```swift
/// // In ConversationView, inside the milestone onChange block:
/// MilestoneCelebrationView(
///     milestone: hit,
///     triggerID: lastMilestoneFiredAt,
///     isParticleActive: $showCelebrationParticles
/// )
/// ```
struct MilestoneCelebrationView: View {
    let milestone: Int
    /// Equatable trigger passed to `.openMicCelebrationKeyframes`.
    let triggerID: Int
    @Binding var isParticleActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background particles (existing Wave 1 system)
            if isParticleActive {
                CelebrationParticleView(particleCount: particleCount)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            // Foreground milestone badge with keyframe animation
            if !reduceMotion {
                milestoneBadge
                    .openMicCelebrationKeyframes(trigger: triggerID)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Badge

    private var milestoneBadge: some View {
        VStack(spacing: OpenMicTheme.Spacing.xs) {
            Text(badgeEmoji)
                .font(.system(size: 36))
                .accessibilityHidden(true)

            Text(badgeTitle)
                .font(OpenMicTheme.Typography.headline)
                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

            Text(badgeSubtitle)
                .font(OpenMicTheme.Typography.caption)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
        }
        .padding(.horizontal, OpenMicTheme.Spacing.xl)
        .padding(.vertical, OpenMicTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .fill(OpenMicTheme.Colors.surfaceGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                        .strokeBorder(OpenMicTheme.Colors.borderMedium, lineWidth: 0.5)
                )
        )
        .shadow(
            color: OpenMicTheme.Colors.glowCyan,
            radius: 20,
            x: 0,
            y: 0
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badgeTitle). \(badgeSubtitle)")
    }

    // MARK: - Helpers

    private var particleCount: Int {
        ConversationCelebrationContext.conversationMilestone(milestone).particleCount
    }

    private var badgeEmoji: String {
        if milestone >= 100 { return "🏆" }
        if milestone >= 50  { return "⭐" }
        return "🎯"
    }

    private var badgeTitle: String {
        "\(milestone) Messages"
    }

    private var badgeSubtitle: String {
        switch milestone {
        case 100: return "Century milestone"
        case 50:  return "Halfway to 100"
        default:  return "Conversation milestone"
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Layers a `CelebrationParticleView` + keyframe badge for a conversation milestone.
    ///
    /// Pass the same `triggerID` integer used to detect the milestone; the modifier fires
    /// the keyframe animation once per unique value.
    func conversationMilestoneCelebration(
        milestone: Int,
        triggerID: Int,
        isParticleActive: Binding<Bool>
    ) -> some View {
        self.overlay(
            MilestoneCelebrationView(
                milestone: milestone,
                triggerID: triggerID,
                isParticleActive: isParticleActive
            )
        )
    }
}
