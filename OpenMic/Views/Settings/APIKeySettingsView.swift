import SwiftUI

struct APIKeySettingsView: View {
    @Environment(AppServices.self) private var appServices
    @State private var viewModel: SettingsViewModel?
    @State private var appeared = false

    private var effectiveTier: SubscriptionTier {
        appServices.effectiveTier
    }

    private var isBYOKMode: Bool {
        effectiveTier == .byok
    }

    private var selectedProvider: AIProviderType? {
        guard let raw = UserDefaults.standard.string(forKey: "selectedProvider") else {
            return nil
        }
        return AIProviderType(rawValue: raw)
    }

    private var appleVisibilityNote: String? {
        if ProviderAccessPolicy.canShowInUI(
            provider: .apple,
            tier: effectiveTier,
            surface: .iPhone
        ) {
            return nil
        }

        if !AIProviderType.apple.isAvailable {
            return "Apple Intelligence is unavailable in this build."
        }

        if !AIProviderType.apple.isAllowedForTier(effectiveTier) {
            return "Apple Intelligence unlocks on Premium and BYOK."
        }

        if !AIProviderType.apple.isRuntimeAvailable {
            return "Apple Intelligence appears on iOS 26 or later."
        }

        return "Apple Intelligence is currently unavailable."
    }

    private var visibleCloudProviders: [AIProviderType] {
        AIProviderType.cloudProviders.filter { provider in
            ProviderAccessPolicy.canShowInUI(
                provider: provider,
                tier: effectiveTier,
                surface: .iPhone
            )
        }
    }

    private var visibleSelfHostedProviders: [AIProviderType] {
        AIProviderType.selfHostedProviders.filter { provider in
            ProviderAccessPolicy.canShowInUI(
                provider: provider,
                tier: effectiveTier,
                surface: .iPhone
            )
        }
    }

    private var visibleLocalProviders: [AIProviderType] {
        AIProviderType.localProviders.filter { provider in
            ProviderAccessPolicy.canShowInUI(
                provider: provider,
                tier: effectiveTier,
                surface: .iPhone
            )
        }
    }

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: OpenMicTheme.Spacing.xl) {
                    if let selectedProvider {
                        CurrentProviderStatus(provider: selectedProvider)
                    }

                    if !isBYOKMode {
                        ManagedModeNotice()
                    }

                    if let appleVisibilityNote {
                        AppleVisibilityNote(text: appleVisibilityNote)
                    }

                    // Cloud providers section
                    VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                        SectionHeader(
                            icon: "cloud.fill",
                            title: "Cloud",
                            subtitle: isBYOKMode
                                ? "Direct provider access with your API keys"
                                : "Managed mode recommended. Keys are optional."
                        )

                        ForEach(Array(visibleCloudProviders.enumerated()), id: \.element.id) { index, provider in
                            if let viewModel {
                                ProviderCard(
                                    provider: provider,
                                    viewModel: viewModel,
                                    isBYOKMode: isBYOKMode,
                                    isActive: selectedProvider == provider
                                )
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.08),
                                    value: appeared
                                )
                            }
                        }
                    }

                    // Self-hosted providers section
                    if !visibleSelfHostedProviders.isEmpty {
                        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                            SectionHeader(
                                icon: "server.rack",
                                title: "Self-Hosted",
                                subtitle: "Your own servers, your own rules"
                            )

                            ForEach(Array(visibleSelfHostedProviders.enumerated()), id: \.element.id) { index, provider in
                                SelfHostedProviderCard(
                                    provider: provider,
                                    isActive: selectedProvider == provider
                                )
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 12)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8)
                                            .delay(Double(visibleCloudProviders.count + index) * 0.08),
                                        value: appeared
                                    )
                            }
                        }
                    }

                    // Local providers section
                    VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                        SectionHeader(
                            icon: "internaldrive.fill",
                            title: "On-Device",
                            subtitle: "Private, free, no internet needed"
                        )

                        ForEach(Array(visibleLocalProviders.enumerated()), id: \.element.id) { index, provider in
                            LocalProviderCard(
                                provider: provider,
                                isActive: selectedProvider == provider
                            )
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(visibleCloudProviders.count + visibleSelfHostedProviders.count + index) * 0.08),
                                    value: appeared
                                )
                        }
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.top, OpenMicTheme.Spacing.sm)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
            }
        }
        .navigationTitle("AI Providers")
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(appServices: appServices)
            }
            withAnimation { appeared = true }
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)

            Text(title.uppercased())
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)

            Text("  \(subtitle)")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary.opacity(0.6))

            Spacer()
        }
        .padding(.horizontal, OpenMicTheme.Spacing.xs)
    }
}

private struct CurrentProviderStatus: View {
    let provider: AIProviderType

    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OpenMicTheme.Colors.success)

            Text("Current provider: \(provider.displayName)")
                .font(OpenMicTheme.Typography.caption)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, OpenMicTheme.Spacing.sm)
    }
}

private struct ManagedModeNotice: View {
    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OpenMicTheme.Colors.success)

            Text("Managed mode is active. You can chat without adding API keys.")
                .font(OpenMicTheme.Typography.caption)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, OpenMicTheme.Spacing.sm)
    }
}

private struct AppleVisibilityNote: View {
    let text: String

    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            Image(systemName: "apple.logo")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)

            Text(text)
                .font(OpenMicTheme.Typography.caption)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, OpenMicTheme.Spacing.sm)
    }
}

