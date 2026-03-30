import SwiftUI

struct ProviderCard: View {
    let provider: AIProviderType
    @Bindable var viewModel: SettingsViewModel
    let isBYOKMode: Bool
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

    private var actionLabel: String {
        if hasKey {
            return "Update"
        }
        return isBYOKMode ? "Add Key" : "Optional Key"
    }

    private var missingKeyMessage: String {
        if isBYOKMode {
            return provider.apiKeyHelpText ?? "Add your \(provider.displayName) API key."
        }
        return "Managed mode handles this provider for you. Add a key only if you enable Power User Mode."
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
                            AnimatedCheckmark(
                                isComplete: hasKey,
                                size: 22,
                                color: OpenMicTheme.Colors.success,
                                lineWidth: 2
                            )
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
                        Text(actionLabel)
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

            if !hasKey, !isEditing {
                Divider()
                    .background(brandColor.opacity(0.15))

                HStack(alignment: .top, spacing: OpenMicTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxxs) {
                        Text(missingKeyMessage)
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }

                    Spacer(minLength: OpenMicTheme.Spacing.sm)

                    if let portalURL = provider.apiKeyPortalURL {
                        Link(destination: portalURL) {
                            HStack(spacing: OpenMicTheme.Spacing.xxs) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Get Key")
                                    .font(OpenMicTheme.Typography.caption)
                            }
                            .foregroundStyle(brandColor)
                            .padding(.horizontal, OpenMicTheme.Spacing.sm)
                            .padding(.vertical, OpenMicTheme.Spacing.xxs)
                            .background(
                                Capsule().fill(brandColor.opacity(0.12))
                            )
                            .overlay(
                                Capsule().strokeBorder(brandColor.opacity(0.25), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.vertical, OpenMicTheme.Spacing.sm)
            }

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
