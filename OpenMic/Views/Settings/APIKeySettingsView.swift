import SwiftUI

struct APIKeySettingsView: View {
    @Environment(AppServices.self) private var appServices
    @State private var viewModel: SettingsViewModel?
    @State private var appeared = false

    private var effectiveTier: SubscriptionTier {
        appServices.effectiveTier
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

                    if let appleVisibilityNote {
                        AppleVisibilityNote(text: appleVisibilityNote)
                    }

                    // Cloud providers section
                    VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                        SectionHeader(
                            icon: "cloud.fill",
                            title: "Cloud",
                            subtitle: "Powerful models, needs an API key"
                        )

                        ForEach(Array(visibleCloudProviders.enumerated()), id: \.element.id) { index, provider in
                            if let viewModel {
                                ProviderCard(
                                    provider: provider,
                                    viewModel: viewModel,
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

// MARK: - Provider Card (Cloud)

private struct ProviderCard: View {
    let provider: AIProviderType
    @Bindable var viewModel: SettingsViewModel
    let isActive: Bool
    @State private var isEditing = false
    @State private var editedKey = ""

    private var hasKey: Bool {
        let key = viewModel.apiKeys[provider] ?? ""
        return !key.isEmpty
    }

    private var brandColor: Color {
        OpenMicTheme.Colors.providerColor(provider)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: OpenMicTheme.Spacing.md) {
                // Brand logo
                BrandLogoCard(provider, size: 52)

                // Provider info
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxxs) {
                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Text(provider.displayName)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        if isActive {
                            Text("Active")
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(OpenMicTheme.Colors.success.opacity(0.12))
                                )
                                .overlay(
                                    Capsule().strokeBorder(OpenMicTheme.Colors.success.opacity(0.25), lineWidth: 0.5)
                                )
                        }

                        if hasKey {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(OpenMicTheme.Colors.success)
                        }
                    }

                    Text(provider.tagline)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }

                Spacer()

                // Action button
                if !isEditing {
                    Button {
                        editedKey = viewModel.apiKeys[provider] ?? ""
                        withAnimation(OpenMicTheme.Animation.fast) {
                            isEditing = true
                        }
                    } label: {
                        Text(hasKey ? "Update" : "Add Key")
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(hasKey ? OpenMicTheme.Colors.textTertiary : brandColor)
                            .padding(.horizontal, OpenMicTheme.Spacing.sm)
                            .padding(.vertical, OpenMicTheme.Spacing.xxs)
                            .background(
                                Capsule().fill(
                                    hasKey
                                        ? OpenMicTheme.Colors.surfaceGlass
                                        : brandColor.opacity(0.15)
                                )
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    hasKey
                                        ? Color.white.opacity(0.06)
                                        : brandColor.opacity(0.3),
                                    lineWidth: 0.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(OpenMicTheme.Spacing.md)

            // Expanded key input
            if isEditing {
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Divider()
                        .background(brandColor.opacity(0.2))

                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(brandColor.opacity(0.6))

                        SecureField("Paste your API key", text: $editedKey)
                            .font(OpenMicTheme.Typography.body)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .tint(brandColor)
                    }
                    .padding(OpenMicTheme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: OpenMicTheme.Radius.sm)
                            .fill(OpenMicTheme.Colors.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: OpenMicTheme.Radius.sm)
                            .strokeBorder(brandColor.opacity(0.15), lineWidth: 0.5)
                    )

                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Button("Cancel") {
                            withAnimation(OpenMicTheme.Animation.fast) {
                                isEditing = false
                            }
                        }
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, OpenMicTheme.Spacing.md)
                        .padding(.vertical, OpenMicTheme.Spacing.xs)

                        Spacer()

                        Button {
                            viewModel.saveKey(for: provider, key: editedKey)
                            Haptics.tap()
                            withAnimation(OpenMicTheme.Animation.fast) {
                                isEditing = false
                            }
                        } label: {
                            Text("Save")
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, OpenMicTheme.Spacing.lg)
                                .padding(.vertical, OpenMicTheme.Spacing.xs)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [brandColor, brandColor.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(editedKey.isEmpty)
                        .opacity(editedKey.isEmpty ? 0.5 : 1)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.bottom, OpenMicTheme.Spacing.md)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .fill(.ultraThinMaterial.opacity(0.7))
        )
        .overlay(
                    RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    isActive ? OpenMicTheme.Colors.success.opacity(0.35) : (hasKey ? brandColor.opacity(0.25) : Color.white.opacity(0.08)),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(provider.displayName), \(isActive ? "active, " : "")\(hasKey ? "configured" : "not configured")"
        )
    }
}

// MARK: - Local Provider Card

private struct LocalProviderCard: View {
    let provider: AIProviderType
    let isActive: Bool

    private var brandColor: Color {
        OpenMicTheme.Colors.providerColor(provider)
    }

    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.md) {
            BrandLogoCard(provider, size: 52)

            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxxs) {
                HStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text(provider.displayName)
                        .font(OpenMicTheme.Typography.headline)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                    if isActive {
                        Text("Active")
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(OpenMicTheme.Colors.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(OpenMicTheme.Colors.success.opacity(0.12))
                            )
                            .overlay(
                                Capsule().strokeBorder(OpenMicTheme.Colors.success.opacity(0.25), lineWidth: 0.5)
                            )
                    }
                }

                Text(provider.tagline)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }

            Spacer()

            if provider.isAvailable {
                Text("Free")
                    .font(OpenMicTheme.Typography.micro)
                    .foregroundStyle(OpenMicTheme.Colors.success)
                    .padding(.horizontal, OpenMicTheme.Spacing.sm)
                    .padding(.vertical, OpenMicTheme.Spacing.xxs)
                    .background(
                        Capsule().fill(OpenMicTheme.Colors.success.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(OpenMicTheme.Colors.success.opacity(0.2), lineWidth: 0.5)
                    )
            } else {
                Text("Coming Soon")
                    .font(OpenMicTheme.Typography.micro)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    .padding(.horizontal, OpenMicTheme.Spacing.sm)
                    .padding(.vertical, OpenMicTheme.Spacing.xxs)
                    .background(
                        Capsule().fill(OpenMicTheme.Colors.surfaceGlass)
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            }
        }
        .padding(OpenMicTheme.Spacing.md)
        .opacity(provider.isAvailable ? 1.0 : 0.6)
        .background(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .fill(.ultraThinMaterial.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isActive ? OpenMicTheme.Colors.success.opacity(0.35) : Color.white.opacity(0.08),
                            Color.white.opacity(0.03),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .accessibilityLabel(
            "\(provider.displayName), \(isActive ? "active, " : "")\(provider.isAvailable ? "free, no API key needed" : "coming soon")"
        )
    }
}

// MARK: - Self-Hosted Provider Card

private struct SelfHostedProviderCard: View {
    let provider: AIProviderType
    let isActive: Bool
    @State private var baseURL: String = ""
    @State private var isEditing = false
    @State private var isTesting = false
    @State private var testResult: Bool?

    private var brandColor: Color {
        OpenMicTheme.Colors.providerColor(provider)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: OpenMicTheme.Spacing.md) {
                BrandLogoCard(provider, size: 52)

                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxxs) {
                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Text(provider.displayName)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        if isActive {
                            Text("Active")
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(OpenMicTheme.Colors.success.opacity(0.12))
                                )
                                .overlay(
                                    Capsule().strokeBorder(OpenMicTheme.Colors.success.opacity(0.25), lineWidth: 0.5)
                                )
                        }

                        Text("Self-Hosted")
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(brandColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(brandColor.opacity(0.12))
                            )
                    }

                    Text(provider.tagline)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }

                Spacer()

                if !isEditing {
                    Button {
                        baseURL = UserDefaults.standard.string(forKey: "openclawBaseURL") ?? ""
                        withAnimation(OpenMicTheme.Animation.fast) {
                            isEditing = true
                        }
                    } label: {
                        Text("Configure")
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(brandColor)
                            .padding(.horizontal, OpenMicTheme.Spacing.sm)
                            .padding(.vertical, OpenMicTheme.Spacing.xxs)
                            .background(
                                Capsule().fill(brandColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule().strokeBorder(brandColor.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(OpenMicTheme.Spacing.md)

            if isEditing {
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Divider()
                        .background(brandColor.opacity(0.2))

                    VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                        Text("Base URL")
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                        HStack(spacing: OpenMicTheme.Spacing.xs) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                                .foregroundStyle(brandColor.opacity(0.6))

                            TextField("http://your-server:8101", text: $baseURL)
                                .font(OpenMicTheme.Typography.body)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .tint(brandColor)
                        }
                        .padding(OpenMicTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.sm)
                                .fill(OpenMicTheme.Colors.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.sm)
                                .strokeBorder(brandColor.opacity(0.15), lineWidth: 0.5)
                        )
                    }

                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Button("Cancel") {
                            withAnimation(OpenMicTheme.Animation.fast) {
                                isEditing = false
                                testResult = nil
                            }
                        }
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, OpenMicTheme.Spacing.md)
                        .padding(.vertical, OpenMicTheme.Spacing.xs)

                        Button {
                            testConnection()
                        } label: {
                            HStack(spacing: 4) {
                                if isTesting {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .tint(.white)
                                } else {
                                    Image(systemName: testResult == true ? "checkmark" : "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(testResult == true ? "Connected" : "Test")
                                    .font(OpenMicTheme.Typography.caption)
                            }
                            .foregroundStyle(testResult == true ? OpenMicTheme.Colors.success : OpenMicTheme.Colors.textSecondary)
                            .padding(.horizontal, OpenMicTheme.Spacing.sm)
                            .padding(.vertical, OpenMicTheme.Spacing.xs)
                            .background(
                                Capsule().fill(OpenMicTheme.Colors.surfaceGlass)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isTesting)

                        Spacer()

                        Button {
                            UserDefaults.standard.set(baseURL, forKey: "openclawBaseURL")
                            Haptics.tap()
                            withAnimation(OpenMicTheme.Animation.fast) {
                                isEditing = false
                            }
                        } label: {
                            Text("Save")
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, OpenMicTheme.Spacing.lg)
                                .padding(.vertical, OpenMicTheme.Spacing.xs)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [brandColor, brandColor.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(baseURL.isEmpty)
                        .opacity(baseURL.isEmpty ? 0.5 : 1)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.bottom, OpenMicTheme.Spacing.md)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .fill(.ultraThinMaterial.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isActive ? OpenMicTheme.Colors.success.opacity(0.35) : brandColor.opacity(0.25),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(provider.displayName), \(isActive ? "active, " : "")self-hosted")
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                let provider = try AIProviderFactory.create(
                    type: .openclaw,
                    apiKey: nil
                )
                let result = try await provider.validateKey()
                testResult = result
            } catch {
                testResult = false
            }
            isTesting = false
        }
    }
}
