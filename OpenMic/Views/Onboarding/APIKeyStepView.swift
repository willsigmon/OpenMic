import SwiftUI

struct APIKeyStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var showContent = false
    @State private var selectedCategory: ProviderCategory = .cloud

    enum ProviderCategory: String, CaseIterable {
        case cloud = "Cloud"
        case local = "On-Device"
    }

    private var visibleCloudProviders: [AIProviderType] {
        AIProviderType.cloudProviders.filter { provider in
            ProviderAccessPolicy.canShowInUI(
                provider: provider,
                tier: viewModel.effectiveTier,
                surface: .iPhone
            )
        }
    }

    private var visibleLocalProviders: [AIProviderType] {
        AIProviderType.localProviders.filter { provider in
            ProviderAccessPolicy.canShowInUI(
                provider: provider,
                tier: viewModel.effectiveTier,
                surface: .iPhone
            )
        }
    }

    private func providers(for category: ProviderCategory) -> [AIProviderType] {
        category == .cloud ? visibleCloudProviders : visibleLocalProviders
    }

    private func selectFirstAvailableProvider(for category: ProviderCategory) {
        if let provider = providers(for: category).first {
            viewModel.selectedProvider = provider
        }
    }

    private var appleVisibilityNote: String? {
        if ProviderAccessPolicy.canShowInUI(
            provider: .apple,
            tier: viewModel.effectiveTier,
            surface: .iPhone
        ) {
            return nil
        }

        if !AIProviderType.apple.isAvailable {
            return "Apple Intelligence is unavailable in this build."
        }

        if !AIProviderType.apple.isAllowedForTier(viewModel.effectiveTier) {
            return "Apple Intelligence unlocks on Premium and BYOK."
        }

        if !AIProviderType.apple.isRuntimeAvailable {
            return "Apple Intelligence appears on iOS 26 or later."
        }

        return "Apple Intelligence is currently unavailable."
    }

    private var categorySummary: String {
        switch selectedCategory {
        case .cloud:
            if viewModel.effectiveTier == .byok {
                return "Cloud models need your API key in Power User Mode."
            }
            return "Managed mode is active. API keys are optional."
        case .local:
            return "On-device models are private and key-free."
        }
    }

    private var selectedProviderKeyPortalURL: URL? {
        viewModel.selectedProvider.apiKeyPortalURL
    }

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OpenMicTheme.Spacing.huge)

                // Hero — animated brand logo of selected provider
                ZStack {
                    // Glow ring behind the logo
                    Circle()
                        .fill(OpenMicTheme.Colors.providerColor(viewModel.selectedProvider))
                        .frame(width: 100, height: 100)
                        .blur(radius: 30)
                        .opacity(showContent ? 0.4 : 0)

                    BrandLogoCard(viewModel.selectedProvider, size: 72)
                        .scaleEffect(showContent ? 1 : 0.7)
                }
                .animation(OpenMicTheme.Animation.springy, value: viewModel.selectedProvider)
                .padding(.bottom, OpenMicTheme.Spacing.lg)

                // Title + subtitle
                VStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text("Pick Your Brain")
                        .font(OpenMicTheme.Typography.title)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                    Text("Pick where your AI runs.")
                        .font(OpenMicTheme.Typography.body)
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OpenMicTheme.Spacing.xl)
                }
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, OpenMicTheme.Spacing.lg)

                // Cloud / On-Device toggle
                HStack(spacing: 0) {
                    ForEach(ProviderCategory.allCases, id: \.self) { category in
                        Button {
                            withAnimation(OpenMicTheme.Animation.fast) {
                                selectedCategory = category
                                // Auto-select first provider in this category.
                                selectFirstAvailableProvider(for: category)
                            }
                        } label: {
                            Text(category.rawValue)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(
                                    selectedCategory == category
                                        ? OpenMicTheme.Colors.textPrimary
                                        : OpenMicTheme.Colors.textTertiary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, OpenMicTheme.Spacing.xs)
                                .background(
                                    selectedCategory == category
                                        ? Capsule().fill(OpenMicTheme.Colors.surfaceGlass)
                                        : nil
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule().fill(OpenMicTheme.Colors.surfaceSecondary)
                )
                .padding(.horizontal, OpenMicTheme.Spacing.xxxl)
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, OpenMicTheme.Spacing.xs)

                Text(categorySummary)
                    .font(OpenMicTheme.Typography.micro)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    .opacity(showContent ? 1 : 0)
                    .padding(.bottom, OpenMicTheme.Spacing.sm)

                // Provider grid
                let providers = providers(for: selectedCategory)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: OpenMicTheme.Spacing.sm) {
                        ForEach(providers) { provider in
                            OnboardingProviderChip(
                                provider: provider,
                                isSelected: viewModel.selectedProvider == provider
                            ) {
                                withAnimation(OpenMicTheme.Animation.springy) {
                                    viewModel.selectedProvider = provider
                                }
                            }
                        }
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.xl)
                }
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, OpenMicTheme.Spacing.lg)

                if let appleVisibilityNote {
                    GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                        HStack(spacing: OpenMicTheme.Spacing.sm) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 14))
                                .foregroundStyle(OpenMicTheme.Colors.textSecondary)

                            Text(appleVisibilityNote)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.xl)
                    .padding(.bottom, OpenMicTheme.Spacing.sm)
                    .transition(.opacity)
                }

                // API key field (only for cloud providers)
                if selectedCategory == .cloud {
                    GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                            HStack(spacing: OpenMicTheme.Spacing.sm) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(
                                        OpenMicTheme.Colors.providerColor(viewModel.selectedProvider).opacity(0.6)
                                    )

                                SecureField(
                                    viewModel.effectiveTier == .byok
                                        ? "Paste your API key"
                                        : "Optional: paste your own API key",
                                    text: $viewModel.apiKey
                                )
                                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .tint(OpenMicTheme.Colors.providerColor(viewModel.selectedProvider))
                            }

                            if let portalURL = selectedProviderKeyPortalURL {
                                Link(destination: portalURL) {
                                    HStack(spacing: OpenMicTheme.Spacing.xxxs) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Need a key? Open \(viewModel.selectedProvider.displayName)")
                                            .font(OpenMicTheme.Typography.micro)
                                    }
                                    .foregroundStyle(OpenMicTheme.Colors.providerColor(viewModel.selectedProvider))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.xl)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                } else {
                    // Local provider info
                    GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                        HStack(spacing: OpenMicTheme.Spacing.sm) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(OpenMicTheme.Colors.success)

                            Text("No API key needed. Runs privately on your device.")
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.xl)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }

                Spacer()

                // Action buttons
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Button("Continue") {
                        viewModel.advance()
                    }
                    .buttonStyle(.openMicPrimary)
                    .disabled(
                        selectedCategory == .cloud
                        && viewModel.effectiveTier == .byok
                        && viewModel.apiKey.isEmpty
                    )

                    Button("Skip for Now") {
                        viewModel.advance()
                    }
                    .buttonStyle(.openMicGhost)
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xl)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
            }
        }
        .onAppear {
            selectFirstAvailableProvider(for: selectedCategory)
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
        }
    }
}

// MARK: - Onboarding Provider Chip

private struct OnboardingProviderChip: View {
    let provider: AIProviderType
    let isSelected: Bool
    let action: () -> Void

    private var brandColor: Color {
        OpenMicTheme.Colors.providerColor(provider)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: OpenMicTheme.Spacing.xs) {
                // Brand logo in a circle
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? brandColor.opacity(0.2)
                                : OpenMicTheme.Colors.surfaceSecondary
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected
                                        ? brandColor.opacity(0.5)
                                        : Color.white.opacity(0.06),
                                    lineWidth: isSelected ? 1.5 : 0.5
                                )
                        )

                    BrandLogo(provider, size: 36, tint: isSelected ? brandColor : OpenMicTheme.Colors.textTertiary)
                }

                Text(provider.shortName)
                    .font(OpenMicTheme.Typography.micro)
                    .foregroundStyle(
                        isSelected
                            ? OpenMicTheme.Colors.textPrimary
                            : OpenMicTheme.Colors.textTertiary
                    )
            }
            .padding(.vertical, OpenMicTheme.Spacing.xxs)
            .contentShape(Rectangle())
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(OpenMicTheme.Animation.fast, value: isSelected)
        .accessibilityLabel(provider.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
