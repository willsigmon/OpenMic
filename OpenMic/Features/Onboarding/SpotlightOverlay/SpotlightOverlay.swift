import SwiftUI

// MARK: - Spotlight Overlay

/// OpenMic-native spotlight overlay for first-run feature onboarding.
///
/// Tooltip is built from GlassCard + OpenMicTheme tokens, so it looks
/// like it belongs to the "Midnight Dashboard" car-cockpit interface.
/// Accent dots use the cyan gradient; the Next CTA pulses with a glow.
struct SpotlightOverlay: View {

    // MARK: - Properties

    let targetRect: CGRect
    /// Container size supplied by the parent GeometryReader. Avoids the
    /// deprecated UIScreen.main.bounds and is correct for iPad multitasking
    /// and Stage Manager.
    let containerSize: CGSize
    let title: String
    let description: String
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Constants

    private let spotlightPadding: CGFloat = 12
    private let spotlightCornerRadius: CGFloat = OpenMicTheme.Radius.lg
    private let tooltipMaxWidth: CGFloat = 292

    // MARK: - Body

    var body: some View {
        ZStack {
            dimmedBackground
            tooltipCard
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    // MARK: - Dimmed Background

    /// compositingGroup() is required: .destinationOut only punches out
    /// within the compositing layer, not directly against the screen.
    private var dimmedBackground: some View {
        // Midnight Dashboard uses near-black; 0.88 opacity preserves cockpit feel
        Color(hex: 0x0A0A0F)
            .opacity(0.88)
            .mask(
                Rectangle()
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: spotlightCornerRadius,
                            style: .continuous
                        )
                        .frame(
                            width: targetRect.width + (spotlightPadding * 2),
                            height: targetRect.height + (spotlightPadding * 2)
                        )
                        .position(x: targetRect.midX, y: targetRect.midY)
                        .blendMode(.destinationOut)
                    )
            )
            .compositingGroup()
            .allowsHitTesting(false)
    }

    // MARK: - Tooltip Card

    private var tooltipCard: some View {
        GlassCard(
            cornerRadius: OpenMicTheme.Radius.xl,
            padding: OpenMicTheme.Spacing.lg
        ) {
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                stepHeader
                titleText
                descriptionText
                actionRow
            }
        }
        .frame(maxWidth: tooltipMaxWidth)
        // Subtle cyan glow — matches the active state language in ConversationView
        .shadow(
            color: OpenMicTheme.Colors.glowCyan,
            radius: 18,
            x: 0,
            y: 0
        )
        .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 8)
        .position(tooltipPosition(for: targetRect))
    }

    // MARK: - Tooltip Subviews

    private var stepHeader: some View {
        HStack {
            Text("\(currentStep) of \(totalSteps)")
                .font(OpenMicTheme.Typography.caption)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)

            Spacer()

            // Dot row — filled dot for current step, outline for others
            HStack(spacing: OpenMicTheme.Spacing.xxs) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(
                            step == currentStep
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        OpenMicTheme.Colors.accentGradientStart,
                                        OpenMicTheme.Colors.accentGradientEnd
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                              )
                            : AnyShapeStyle(OpenMicTheme.Colors.borderMedium)
                        )
                        .frame(width: 7, height: 7)
                        .animation(OpenMicTheme.Animation.springy, value: currentStep)
                }
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(OpenMicTheme.Typography.headline)
            .foregroundStyle(OpenMicTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var descriptionText: some View {
        Text(description)
            .font(OpenMicTheme.Typography.body)
            .foregroundStyle(OpenMicTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionRow: some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            Button(action: onSkip) {
                Text("Skip")
                    .font(OpenMicTheme.Typography.callout)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text(currentStep == totalSteps ? "Done" : "Next")
                        .font(OpenMicTheme.Typography.callout)
                    if currentStep < totalSteps {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                }
                .foregroundStyle(OpenMicTheme.Colors.background)
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.vertical, OpenMicTheme.Spacing.xs)
                .background(
                    OpenMicTheme.Gradients.accent,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .glow(
                color: OpenMicTheme.Colors.glowCyan,
                radius: 10,
                isActive: true
            )
        }
    }

    // MARK: - Tooltip Positioning

    private func tooltipPosition(for rect: CGRect) -> CGPoint {
        let tooltipHeight: CGFloat = 210
        let margin: CGFloat = 20

        let spaceBelow = containerSize.height - rect.maxY - 60
        let spaceAbove = rect.minY - 60

        let rawY: CGFloat
        if spaceBelow >= tooltipHeight || spaceBelow > spaceAbove {
            rawY = rect.maxY + tooltipHeight / 2 + 16
        } else {
            rawY = rect.minY - tooltipHeight / 2 - 16
        }

        let clampedY = max(
            tooltipHeight / 2 + 50,
            min(rawY, containerSize.height - tooltipHeight / 2 - 50)
        )

        // Nudge tooltip horizontally if target is near an edge
        let rawX = rect.midX
        let clampedX = max(
            tooltipMaxWidth / 2 + margin,
            min(rawX, containerSize.width - tooltipMaxWidth / 2 - margin)
        )

        return CGPoint(x: clampedX, y: clampedY)
    }
}
