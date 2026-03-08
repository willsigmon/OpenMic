import SwiftUI

struct LocalProviderCard: View {
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
