import SwiftUI
import SwiftData
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "ConversationListView")

struct ConversationListView: View {
    let onResumeConversation: (Conversation) -> Void
    @Environment(AppServices.self) private var appServices
    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var conversations: [Conversation]

    @State private var emptyStateVisible = false
    @State private var conversationToDelete: Conversation?

    var body: some View {
        NavigationStack {
            ZStack {
                OpenMicTheme.Colors.background.ignoresSafeArea()

                Group {
                    if conversations.isEmpty {
                        emptyState
                    } else {
                        conversationList
                    }
                }
            }
            .navigationTitle("History")
            .confirmationDialog(
                "Delete Conversation?",
                isPresented: Binding(
                    get: { conversationToDelete != nil },
                    set: { if !$0 { conversationToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let conversation = conversationToDelete {
                        Haptics.thud()
                        withAnimation {
                            do {
                                try appServices.conversationStore.delete(conversation)
                            } catch {
                                log.error("Failed to delete conversation: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                        conversationToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    conversationToDelete = nil
                }
            } message: {
                Text("This conversation will be permanently deleted.")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: OpenMicTheme.Spacing.lg) {
            // Animated icon
            ZStack {
                // Breathing glow
                Circle()
                    .fill(OpenMicTheme.Colors.glowCyan)
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                    .opacity(emptyStateVisible ? 0.5 : 0.2)

                GradientIcon(
                    systemName: "bubble.left.and.bubble.right",
                    gradient: OpenMicTheme.Gradients.accent,
                    size: 72,
                    iconSize: 30,
                    glowColor: OpenMicTheme.Colors.glowCyan,
                    isAnimated: true
                )
            }
            .scaleEffect(emptyStateVisible ? 1.0 : 0.8)
            .opacity(emptyStateVisible ? 1.0 : 0)
            .accessibilityHidden(true)

            VStack(spacing: OpenMicTheme.Spacing.xs) {
                Text(Microcopy.EmptyState.historyTitle)
                    .font(OpenMicTheme.Typography.title)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                Text(Microcopy.EmptyState.historySubtitle)
                    .font(OpenMicTheme.Typography.body)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OpenMicTheme.Spacing.xxxl)
            }
            .opacity(emptyStateVisible ? 1.0 : 0)
            .offset(y: emptyStateVisible ? 0 : 10)
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(OpenMicTheme.Animation.smooth.delay(0.2)) {
                emptyStateVisible = true
            }
        }
    }

    @ViewBuilder
    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: OpenMicTheme.Spacing.sm) {
                ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                    ConversationRow(conversation: conversation)
                        .onTapGesture {
                            Haptics.tap()
                            onResumeConversation(conversation)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                conversationToDelete = conversation
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .scrollTransition(.animated.threshold(.visible(0.9))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .sensoryFeedback(.selection, trigger: conversation.id)
                }
            }
            .padding(.horizontal, OpenMicTheme.Spacing.md)
            .padding(.top, OpenMicTheme.Spacing.sm)
        }
    }

}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack(spacing: OpenMicTheme.Spacing.sm) {
                // Provider icon
                ProviderIcon(provider: conversation.provider, size: 36)

                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxs) {
                    Text(conversation.displayTitle)
                        .font(OpenMicTheme.Typography.headline)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Text(conversation.personaName)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)

                        Circle()
                            .fill(OpenMicTheme.Colors.textTertiary)
                            .frame(width: 3, height: 3)

                        Text(conversation.updatedAt, style: .relative)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(conversation.displayTitle), \(conversation.personaName)")
        .accessibilityHint("Opens conversation")
    }
}
