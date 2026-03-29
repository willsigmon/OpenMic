import SwiftUI

struct TopicCategoryCard: View {
    let category: TopicCategory

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
            HStack(spacing: OpenMicTheme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: category.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(category.color)
                }

                Spacer()

                Text("\(category.promptCount)")
                    .font(OpenMicTheme.Typography.micro)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(OpenMicTheme.Typography.headline)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text("\(category.subcategories.count) topics")
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }
        }
        .padding(OpenMicTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            OpenMicTheme.Colors.surfaceGlass.opacity(0.94),
                            OpenMicTheme.Colors.surfaceSecondary.opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                        .fill(.ultraThinMaterial.opacity(0.30))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            category.color.opacity(0.25),
                            OpenMicTheme.Colors.borderMedium.opacity(0.40),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .tiltCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name), \(category.promptCount) prompts")
        .accessibilityHint("Opens topic category")
    }
}
