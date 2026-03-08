import SwiftUI

struct ProviderBadge: View {
    let provider: AIProviderType

    private var tint: Color {
        OpenMicTheme.Colors.providerColor(provider)
    }

    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.xxs) {
            BrandLogo(provider, size: 16)
            Text(provider.shortName)
                .font(OpenMicTheme.Typography.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
        .padding(.horizontal, OpenMicTheme.Spacing.xs)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(tint.opacity(0.30), lineWidth: 0.8)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Provider: \(provider.displayName)")
    }
}
