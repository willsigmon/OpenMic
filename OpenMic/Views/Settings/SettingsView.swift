import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var appServices
    @State private var versionTapCount = 0
    @State private var showPaywall = false
    @State private var showBYOKConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var accountDeletionError: String?

    private var isBYOK: Bool { appServices.authManager.authState.isBYOK }
    private var isAuthenticated: Bool { appServices.authManager.authState.isAuthenticated }
    private var tier: SubscriptionTier { appServices.effectiveTier }

    var body: some View {
        NavigationStack {
            ZStack {
                OpenMicTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OpenMicTheme.Spacing.md) {
                        // Subscription section
                        SettingsSection(title: "Subscription", subtitle: "Manage your plan and usage") {
                            // Current plan row
                            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                                HStack(spacing: OpenMicTheme.Spacing.sm) {
                                    LayeredFeatureIcon(
                                        systemName: "crown",
                                        color: tierColor,
                                        accentShape: .none
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tier.displayName)
                                            .font(OpenMicTheme.Typography.headline)
                                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                                        if tier != .byok {
                                            Text("\(appServices.usageTracker.remainingMinutes) min remaining")
                                                .font(OpenMicTheme.Typography.caption)
                                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                                .contentTransition(.numericText())
                                                .animation(OpenMicTheme.Animation.smooth, value: appServices.usageTracker.remainingMinutes)
                                        } else {
                                            Text("Using your own API keys")
                                                .font(OpenMicTheme.Typography.caption)
                                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                        }
                                    }

                                    Spacer()

                                    if tier == .free || tier == .standard {
                                        Button("Upgrade") {
                                            Haptics.tap()
                                            showPaywall = true
                                        }
                                        .font(OpenMicTheme.Typography.callout)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, OpenMicTheme.Spacing.sm)
                                        .padding(.vertical, OpenMicTheme.Spacing.xs)
                                        .background(OpenMicTheme.Gradients.accent)
                                        .clipShape(Capsule())
                                    }
                                }
                            }

                            SettingsRow(
                                icon: "chart.bar",
                                title: "Usage",
                                color: OpenMicTheme.Colors.listening,
                                destination: UsageDashboardView()
                            )
                        }

                        SettingsSection(title: "AI Providers", subtitle: Microcopy.Settings.aiProviders) {
                            SettingsRow(
                                icon: "cpu",
                                title: "AI Providers",
                                color: OpenMicTheme.Colors.accentGradientStart,
                                destination: APIKeySettingsView()
                            )
                        }

                        SettingsSection(title: "Voice", subtitle: Microcopy.Settings.voice) {
                            SettingsRow(
                                icon: "waveform",
                                title: "Voice Settings",
                                color: OpenMicTheme.Colors.speaking,
                                destination: VoiceSettingsView()
                            )
                        }

                        SettingsSection(title: "Personas", subtitle: Microcopy.Settings.personas) {
                            SettingsRow(
                                icon: "person.crop.circle",
                                title: "Manage Personas",
                                color: OpenMicTheme.Colors.processing,
                                destination: PersonaSettingsView()
                            )
                        }

                        // Advanced section (BYOK toggle)
                        SettingsSection(title: "Advanced") {
                            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                                HStack(spacing: OpenMicTheme.Spacing.sm) {
                                    LayeredFeatureIcon(
                                        systemName: "key",
                                        color: OpenMicTheme.Colors.processing,
                                        accentShape: .none
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Power User Mode")
                                            .font(OpenMicTheme.Typography.headline)
                                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                                        Text("Managed by default. Enable for direct BYOK routing.")
                                            .font(OpenMicTheme.Typography.caption)
                                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { isBYOK },
                                        set: { newValue in
                                            if newValue {
                                                showBYOKConfirm = true
                                            } else {
                                                appServices.authManager.disableBYOKMode()
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(OpenMicTheme.Colors.accentGradientStart)
                                    .accessibilityLabel("Power User Mode")
                                    .accessibilityHint("Switches between managed billing and direct API key connections")
                                }
                            }

                            if isBYOK {
                                GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(OpenMicTheme.Colors.processing)
                                            .accessibilityHidden(true)

                                        Text("Power User Mode — No usage limits, direct API connections")
                                            .font(OpenMicTheme.Typography.caption)
                                            .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                                    }
                                }
                            }
                        }

                        if isAuthenticated {
                            SettingsSection(title: "Account", subtitle: "Authentication and data controls") {
                                SettingsActionCard(
                                    icon: "trash",
                                    title: "Delete Account",
                                    subtitle: "Permanently delete your OpenMic account and cloud data",
                                    color: OpenMicTheme.Colors.error,
                                    isLoading: isDeletingAccount,
                                    role: .destructive
                                ) {
                                    Haptics.tap()
                                    showDeleteAccountConfirm = true
                                }

                                if let accountDeletionError {
                                    GlassCard(
                                        cornerRadius: OpenMicTheme.Radius.md,
                                        padding: OpenMicTheme.Spacing.sm
                                    ) {
                                        Text(accountDeletionError)
                                            .font(OpenMicTheme.Typography.caption)
                                            .foregroundStyle(OpenMicTheme.Colors.error)
                                    }
                                }
                            }
                        }

                        SettingsSection(title: "About", subtitle: Microcopy.Settings.about) {
                            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                                HStack {
                                    HStack(spacing: OpenMicTheme.Spacing.sm) {
                                        LayeredFeatureIcon(
                                            systemName: "info.circle",
                                            color: OpenMicTheme.Colors.textSecondary,
                                            accentShape: .none
                                        )

                                        Text("Version")
                                            .font(OpenMicTheme.Typography.headline)
                                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                    }

                                    Spacer()

                                    Text(versionLabel)
                                        .font(OpenMicTheme.Typography.caption)
                                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                        .contentTransition(.numericText())
                                }
                            }
                            .onTapGesture {
                                versionTapCount += 1
                                Haptics.tap()
                            }
                            .accessibilityLabel("Version \(versionLabel)")
                            .accessibilityAddTraits(.isStaticText)
                        }

                        // Footer
                        Text("Made with love for the open road")
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary.opacity(0.5))
                            .padding(.top, OpenMicTheme.Spacing.lg)
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.md)
                    .padding(.top, OpenMicTheme.Spacing.sm)
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Enable Power User Mode?", isPresented: $showBYOKConfirm) {
            Button("Enable") {
                appServices.authManager.enableBYOKMode()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This disables managed billing and uses your own API keys directly. You'll need to configure keys in AI Providers.")
        }
        .alert("Delete account permanently?", isPresented: $showDeleteAccountConfirm) {
            Button("Delete Account", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Your OpenMic account and server-side data will be permanently removed.")
        }
    }

    private var tierColor: Color {
        switch tier {
        case .free: OpenMicTheme.Colors.textTertiary
        case .standard: OpenMicTheme.Colors.accentGradientStart
        case .premium: OpenMicTheme.Colors.speaking
        case .byok: OpenMicTheme.Colors.processing
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        if versionTapCount >= 7 {
            return "\(version) (you found me!)"
        }
        return version
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }

        isDeletingAccount = true
        accountDeletionError = nil

        do {
            try await appServices.authManager.deleteAccount()
            await appServices.handleAccountDeletionCleanup()
            Haptics.success()
        } catch {
            accountDeletionError = error.localizedDescription
            Haptics.error()
        }

        isDeletingAccount = false
    }
}

// MARK: - Settings Section

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(OpenMicTheme.Typography.micro)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary.opacity(0.6))
                }
            }
            .padding(.horizontal, OpenMicTheme.Spacing.xs)

            content()
        }
        .scrollTransition(.animated.threshold(.visible(0.9))) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.5)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow<Destination: View>: View {
    let icon: String
    let title: String
    let color: Color
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    LayeredFeatureIcon(
                        systemName: icon,
                        color: color,
                        accentShape: .none
                    )

                    Text(title)
                        .font(OpenMicTheme.Typography.headline)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: false)
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title.lowercased())")
    }
}

private struct SettingsActionCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    var isLoading: Bool = false
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    LayeredFeatureIcon(
                        systemName: icon,
                        color: color,
                        accentShape: .none
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        if let subtitle {
                            Text(subtitle)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        }
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .tint(color)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? title)
    }
}
