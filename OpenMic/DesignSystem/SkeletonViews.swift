import SwiftUI

// MARK: - Conversation Row Skeleton

/// Matches ConversationRow layout: 36pt provider icon circle + 2 text lines + relative timestamp.
struct ConversationRowSkeleton: View {
    let index: Int

    init(index: Int = 0) {
        self.index = index
    }

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack(spacing: OpenMicTheme.Spacing.sm) {
                // Provider icon placeholder
                SkeletonShape(
                    width: 36,
                    height: 36,
                    cornerRadius: 18
                )

                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxs) {
                    // Title line
                    SkeletonShape(height: 14)
                    // Persona + timestamp line
                    SkeletonShape(width: 120, height: 10)
                }

                Spacer()

                // Chevron placeholder
                SkeletonShape(width: 8, height: 12, cornerRadius: 2)
            }
        }
        .opacity(1.0 - Double(index) * 0.04)
    }
}

// MARK: - Suggestion Chip Skeleton

/// Matches PromptCard layout: 2-column grid cell, 96pt tall, rounded rect.
struct SuggestionChipSkeleton: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.quaternary)
            .frame(height: 96)
            .shimmer()
    }
}

// MARK: - Provider Card Skeleton

/// Matches ProviderCard layout: 52pt logo circle + name line + status line.
struct ProviderCardSkeleton: View {
    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.md) {
            // Brand logo placeholder
            SkeletonShape(
                width: 52,
                height: 52,
                cornerRadius: OpenMicTheme.Radius.md
            )

            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxs) {
                // Provider name
                SkeletonShape(width: 120, height: 14)
                // Status line
                SkeletonShape(width: 80, height: 10)
            }

            Spacer()

            // Action button placeholder
            SkeletonShape(width: 64, height: 28, cornerRadius: OpenMicTheme.Radius.pill)
        }
        .padding(OpenMicTheme.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Conversation Row Skeletons") {
    ScrollView {
        LazyVStack(spacing: OpenMicTheme.Spacing.sm) {
            ForEach(0..<5, id: \.self) { index in
                ConversationRowSkeleton(index: index)
            }
        }
        .padding(OpenMicTheme.Spacing.md)
    }
    .background(OpenMicTheme.Colors.background)
}

#Preview("Suggestion Chip Skeletons") {
    LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
        spacing: 10
    ) {
        ForEach(0..<4, id: \.self) { _ in
            SuggestionChipSkeleton()
        }
    }
    .padding()
    .background(OpenMicTheme.Colors.background)
}

#Preview("Provider Card Skeletons") {
    VStack(spacing: 12) {
        ForEach(0..<3, id: \.self) { _ in
            ProviderCardSkeleton()
        }
    }
    .padding()
    .background(OpenMicTheme.Colors.background)
}
