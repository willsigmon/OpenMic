import SwiftUI

struct TopicCategoryDetailView: View {
    let category: TopicCategory
    let onSelectPrompt: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: OpenMicTheme.Spacing.xl) {
                    // Category header
                    categoryHeader

                    // Subcategories
                    ForEach(Array(category.subcategories.enumerated()), id: \.element.id) { index, subcategory in
                        subcategorySection(subcategory, index: index)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.top, OpenMicTheme.Spacing.sm)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    // MARK: - Category Header

    @ViewBuilder
    private var categoryHeader: some View {
        HStack(spacing: OpenMicTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: category.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(OpenMicTheme.Typography.title)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                Text("\(category.promptCount) conversation starters")
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }

            Spacer()
        }
        .padding(OpenMicTheme.Spacing.md)
        .glassBackground(cornerRadius: OpenMicTheme.Radius.lg)
    }

    // MARK: - Subcategory Section

    @ViewBuilder
    private func subcategorySection(_ subcategory: TopicSubcategory, index: Int) -> some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(subcategory.name)
                    .font(OpenMicTheme.Typography.headline)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                Text(subcategory.description)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }
            .padding(.horizontal, OpenMicTheme.Spacing.xs)

            // Prompt chips in flow layout
            FlowLayout(spacing: OpenMicTheme.Spacing.xs) {
                ForEach(subcategory.prompts) { prompt in
                    Button {
                        Haptics.tap()
                        onSelectPrompt(prompt.text)
                    } label: {
                        Text(prompt.label)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                            .padding(.horizontal, OpenMicTheme.Spacing.sm)
                            .padding(.vertical, OpenMicTheme.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(category.color.opacity(0.08))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(category.color.opacity(0.18), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(prompt.label)
                    .accessibilityHint("Starts conversation: \(prompt.text)")
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06),
            value: appeared
        )
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
