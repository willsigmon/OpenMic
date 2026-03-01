import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var appServices
    @State private var versionTapCount = 0
    @State private var showPaywall = false
    @State private var showBYOKConfirm = false

    private var isBYOK: Bool { appServices.authManager.authState.isBYOK }
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

                                        Text("Use your own API keys")
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
                                }
                            }

                            if isBYOK {
                                GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(OpenMicTheme.Colors.processing)

                                        Text("Power User Mode — No usage limits, direct API connections")
                                            .font(OpenMicTheme.Typography.caption)
                                            .foregroundStyle(OpenMicTheme.Colors.textSecondary)
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
