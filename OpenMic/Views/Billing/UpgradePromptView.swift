import SwiftUI

struct UpgradePromptView: View {
    @Environment(AppServices.self) private var appServices
    let onDismiss: () -> Void
    let onUpgrade: () -> Void

    @State private var showContent = false

    private var remaining: Int { appServices.usageTracker.remainingMinutes }
    private var tier: SubscriptionTier { appServices.effectiveTier }

    var body: some View {
        VStack(spacing: OpenMicTheme.Spacing.lg) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(OpenMicTheme.Colors.textTertiary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, OpenMicTheme.Spacing.sm)

            VStack(spacing: OpenMicTheme.Spacing.md) {
                // Warning icon
                ZStack {
                    Circle()
                        .fill(OpenMicTheme.Colors.glowAmber)
                        .frame(width: 60, height: 60)
                        .blur(radius: 15)

                    Image(systemName: remaining <= 0 ? "exclamationmark.circle.fill" : "clock.badge.exclamationmark")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(remaining <= 0 ? OpenMicTheme.Colors.error : OpenMicTheme.Colors.processing)
                }

                VStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text(headlineText)
                        .font(OpenMicTheme.Typography.title)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(subtitleText)
                        .font(OpenMicTheme.Typography.body)
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .opacity(showContent ? 1 : 0)

            // Actions
            VStack(spacing: OpenMicTheme.Spacing.sm) {
                Button("Upgrade Now") {
                    Haptics.tap()
                    onUpgrade()
                }
                .buttonStyle(.openMicPrimary)

                Button("Not Now") {
                    onDismiss()
                }
                .font(OpenMicTheme.Typography.headline)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }
            .padding(.horizontal, OpenMicTheme.Spacing.xl)
            .padding(.bottom, OpenMicTheme.Spacing.xxl)
            .opacity(showContent ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.xl)
                .fill(OpenMicTheme.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: OpenMicTheme.Radius.xl)
                        .strokeBorder(OpenMicTheme.Colors.borderMedium, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: -5)
        )
        .onAppear {
            withAnimation(OpenMicTheme.Animation.smooth.delay(0.1)) {
                showContent = true
            }
        }
    }

    private var headlineText: String {
        if remaining <= 0 {
            return "Minutes Exhausted"
        } else if remaining <= 2 {
            return "Running Low"
        } else {
            return "\(remaining) Minutes Left"
        }
    }

    private var subtitleText: String {
        let nextTier: SubscriptionTier = tier == .free ? .standard : .premium
        if remaining <= 0 {
            return "Upgrade to \(nextTier.displayName) for \(nextTier.monthlyMinutes) minutes/month and better voice quality."
        } else {
            return "Upgrade to \(nextTier.displayName) for more minutes and premium voice AI."
        }
    }
}
