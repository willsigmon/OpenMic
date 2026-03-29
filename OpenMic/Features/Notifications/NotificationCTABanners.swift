import SwiftUI
import UserNotifications

// MARK: - NotificationCTABanners
//
// Contextual CTA banners for OpenMic.
// Each hides itself when notification permission is already granted.
// Tapping presents NotificationPermissionView as a sheet.
//
// Usage:
//   FirstConversationNotificationCTA()  — after first completed conversation
//   ProviderSetupNotificationCTA()       — after setting up first API key

// MARK: - Authorization State Helper

@Observable
@MainActor
private final class NotificationAuthState {
    var isAuthorized = false

    func refresh() {
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }
}

// MARK: - Base Banner

private struct NotificationCTABanner: View {
    let icon: String
    let message: String
    let actionLabel: String
    let accentColor: Color

    @State private var authState = NotificationAuthState()
    @State private var showPermissionSheet = false
    @State private var isDismissed = false

    var body: some View {
        if !authState.isAuthorized && !isDismissed {
            bannerContent
                .sheet(isPresented: $showPermissionSheet) {
                    NotificationPermissionView()
                }
                .task { authState.refresh() }
        }
    }

    private var bannerContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                Text(actionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            Spacer(minLength: 0)

            Button {
                isDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassBackground(cornerRadius: OpenMicTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md)
                .strokeBorder(accentColor.opacity(0.20), lineWidth: 0.5)
        )
        .onTapGesture {
            showPermissionSheet = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). \(actionLabel)")
        .accessibilityHint("Double tap to enable notifications")
        .accessibilityAddTraits(.isButton)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Pre-built CTAs

/// Shown after the user completes their first conversation.
struct FirstConversationNotificationCTA: View {
    var body: some View {
        NotificationCTABanner(
            icon: "bell.badge",
            message: "Want conversation reminders?",
            actionLabel: "Turn On Notifications",
            accentColor: OpenMicTheme.Colors.accentGradientStart
        )
    }
}

/// Shown after the user sets up their first API key.
struct ProviderSetupNotificationCTA: View {
    var body: some View {
        NotificationCTABanner(
            icon: "arrow.triangle.2.circlepath",
            message: "We'll notify you when new models drop",
            actionLabel: "Enable Model Alerts",
            accentColor: OpenMicTheme.Colors.processing
        )
    }
}

// MARK: - Previews

#Preview("First Conversation CTA") {
    ZStack(alignment: .bottom) {
        OpenMicTheme.Colors.background.ignoresSafeArea()
        FirstConversationNotificationCTA()
            .padding()
    }
}

#Preview("Provider Setup CTA") {
    ZStack(alignment: .bottom) {
        OpenMicTheme.Colors.background.ignoresSafeArea()
        ProviderSetupNotificationCTA()
            .padding()
    }
}
