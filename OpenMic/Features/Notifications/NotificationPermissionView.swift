import SwiftUI
import UserNotifications

// MARK: - NotificationPermissionView
//
// Pre-permission "value proposition" screen shown BEFORE the OS dialog.
// Dramatically increases opt-in rates by explaining why notifications matter.
//
// Integration: Present as a sheet from MainTabView after onboarding completes.
// Check: @AppStorage("hasSeenNotificationAsk") prevents showing twice.

struct NotificationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasSeenNotificationAsk") private var hasSeenNotificationAsk = false

    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0.0
    @State private var contentOpacity: Double = 0.0
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                micIllustration

                Spacer().frame(height: 32)

                headerText

                Spacer().frame(height: 24)

                valuePropCard

                Spacer()

                actionButtons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear { animateIn() }
    }

    // MARK: - Mic Illustration

    private var micIllustration: some View {
        ZStack {
            Circle()
                .fill(OpenMicTheme.Colors.accentGradientStart.opacity(0.08))
                .frame(width: 140, height: 140)

            Circle()
                .fill(OpenMicTheme.Colors.accentGradientStart.opacity(0.14))
                .frame(width: 100, height: 100)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 44))
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
                .symbolEffect(.bounce, options: .nonRepeating)
        }
        .scaleEffect(iconScale)
        .opacity(iconOpacity)
        .glow(color: OpenMicTheme.Colors.glowCyan, radius: 16)
        .accessibilityHidden(true)
    }

    // MARK: - Header

    private var headerText: some View {
        VStack(spacing: 10) {
            Text("Stay Connected")
                .font(OpenMicTheme.Typography.title)
                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Get the most out of every conversation.")
                .font(OpenMicTheme.Typography.body)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .opacity(contentOpacity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Value Prop Card

    private var valuePropCard: some View {
        GlassCard(
            cornerRadius: OpenMicTheme.Radius.xl,
            padding: OpenMicTheme.Spacing.lg
        ) {
            VStack(alignment: .leading, spacing: 20) {
                benefitRow(
                    icon: "mic.badge",
                    color: OpenMicTheme.Colors.listening,
                    title: "Voice Reminders",
                    subtitle: "Daily check-in reminders to keep conversations flowing"
                )
                benefitRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: OpenMicTheme.Colors.processing,
                    title: "Provider Updates",
                    subtitle: "Know when new AI models become available"
                )
                benefitRow(
                    icon: "brain",
                    color: OpenMicTheme.Colors.speaking,
                    title: "Conversation Insights",
                    subtitle: "Weekly summaries of your most interesting conversations"
                )
            }
        }
        .opacity(contentOpacity)
    }

    @ViewBuilder
    private func benefitRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OpenMicTheme.Typography.headline)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                requestPermission()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .accessibilityHidden(true)
                    Text("Enable Notifications")
                        .font(OpenMicTheme.Typography.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, 16)
                .background(
                    OpenMicTheme.Gradients.accent,
                    in: RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
            .animation(OpenMicTheme.Animation.springy, value: isRequesting)
            .glow(color: OpenMicTheme.Colors.glowCyan, isActive: !isRequesting)
            .accessibilityLabel("Enable Notifications")
            .accessibilityHint("Requests permission to send push notifications")

            Button {
                markSeenAndDismiss()
            } label: {
                Text("Not Now")
                    .font(OpenMicTheme.Typography.callout)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    .frame(minHeight: 44)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Not Now")
            .accessibilityHint("Dismisses this screen without enabling notifications")

            Text("You can enable notifications anytime in Settings.")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .opacity(contentOpacity)
    }

    // MARK: - Logic

    private func animateIn() {
        let reduce = reduceMotion
        withAnimation(
            reduce ? .linear(duration: 0.01) : .spring(response: 0.5, dampingFraction: 0.65)
        ) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(
            (reduce ? .linear(duration: 0.01) : OpenMicTheme.Animation.smooth).delay(reduce ? 0 : 0.18)
        ) {
            contentOpacity = 1.0
        }
    }

    private func requestPermission() {
        isRequesting = true
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            markSeenAndDismiss()
        }
    }

    private func markSeenAndDismiss() {
        hasSeenNotificationAsk = true
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NotificationPermissionView()
}
