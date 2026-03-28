import SwiftUI

struct ConversationBubbleRow: View {
    let bubble: ConversationBubble
    let reaction: String?
    let onReaction: (String) -> Void
    let onCopy: () -> Void

    private var isUser: Bool { bubble.role == .user }
    private var isSystem: Bool { bubble.role == .system }
    private var descriptor: ConversationBubbleDescriptor {
        ConversationBubbleDescriptorFactory.make(from: bubble)
    }

    var body: some View {
        if isSystem {
            systemMarker
        } else {
            chatBubble
        }
    }

    // MARK: - System Marker (provider switch, etc.)

    private var systemMarker: some View {
        HStack(spacing: OpenMicTheme.Spacing.xs) {
            Rectangle()
                .fill(OpenMicTheme.Colors.borderMedium.opacity(0.4))
                .frame(height: 0.5)
            Text(bubble.text)
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .lineLimit(1)
            Rectangle()
                .fill(OpenMicTheme.Colors.borderMedium.opacity(0.4))
                .frame(height: 0.5)
        }
        .padding(.horizontal, OpenMicTheme.Spacing.xl)
        .padding(.vertical, OpenMicTheme.Spacing.xs)
        .accessibilityIdentifier(
            AppAccessibilityID.bubble(bubble.role, id: bubble.id)
        )
        .accessibilityLabel(bubble.text)
    }

    // MARK: - Chat Bubble

    private var chatBubble: some View {
        HStack {
            if isUser { Spacer(minLength: 42) }

            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxs) {
                if let assistantHeader = descriptor.assistantHeader {
                    Text(assistantHeader)
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }

                Text(bubble.text)
                    .font(
                        isUser
                            ? OpenMicTheme.Typography.transcriptUser
                            : OpenMicTheme.Typography.transcriptAssistant
                    )
                    .foregroundStyle(
                        isUser ? Color.white : OpenMicTheme.Colors.textPrimary
                    )
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, OpenMicTheme.Spacing.sm)
            .padding(.vertical, OpenMicTheme.Spacing.xs)
            .frame(maxWidth: 310, alignment: .leading)
            .background(bubbleBackground)
            .overlay(alignment: .bottomTrailing) {
                if let reaction {
                    Text(reaction)
                        .font(.system(size: 13))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(OpenMicTheme.Colors.surfaceGlass.opacity(0.92))
                        )
                        .offset(x: 6, y: 8)
                }
            }
            .contextMenu {
                Button("\u{1F44D} React") { onReaction("\u{1F44D}") }
                Button("\u{2764}\u{FE0F} React") { onReaction("\u{2764}\u{FE0F}") }
                Button("\u{1F602} React") { onReaction("\u{1F602}") }
                Button("\u{1F914} React") { onReaction("\u{1F914}") }
                Divider()
                Button {
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                ShareLink(item: bubble.text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .accessibilityLabel(bubble.text)
            .accessibilityHint("Long press for reactions, copy, or share")

            if !isUser { Spacer(minLength: 42) }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier(
            AppAccessibilityID.bubble(bubble.role, id: bubble.id)
        )
    }

    // MARK: - Background

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                .fill(OpenMicTheme.Gradients.accent)
                .overlay(
                    RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                )
        } else {
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                .fill(OpenMicTheme.Colors.surfaceGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                        .strokeBorder(OpenMicTheme.Colors.borderMedium, lineWidth: 0.8)
                )
        }
    }
}
