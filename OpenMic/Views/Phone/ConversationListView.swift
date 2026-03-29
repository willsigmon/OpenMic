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
    @State private var searchText = ""
    @State private var navBarOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var heroNamespace

    private var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return conversations }
        return conversations.filter { conversation in
            if conversation.displayTitle.lowercased().contains(query) { return true }
            if conversation.personaName.lowercased().contains(query) { return true }
            return conversation.messages.contains { $0.content.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OpenMicTheme.Colors.background.ignoresSafeArea()

                Group {
                    if conversations.isEmpty {
                        emptyState
                    } else if filteredConversations.isEmpty {
                        noResultsState
                    } else {
                        conversationList
                    }
                }
            }
            .navigationTitle(searchText.isEmpty ? "" : "History")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .modifier(OpenMicGlassNavBarModifier(opacity: navBarOpacity))
            .searchable(text: $searchText, prompt: "Search conversations")
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
    private var noResultsState: some View {
        VStack(spacing: OpenMicTheme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .accessibilityHidden(true)

            Text("No results for \"\(searchText)\"")
                .font(OpenMicTheme.Typography.body)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var conversationList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Parallax hero — hidden during search to keep the focus on results.
                if searchText.isEmpty {
                    OpenMicParallaxHeader(
                        height: 200,
                        reduceMotion: reduceMotion,
                        navBarOpacity: $navBarOpacity
                    ) {
                        ConversationListHeroBanner(conversationCount: conversations.count)
                    }
                }

                LazyVStack(spacing: OpenMicTheme.Spacing.sm) {
                ForEach(Array(filteredConversations.enumerated()), id: \.element.id) { index, conversation in
                    NavigationLink {
                        ConversationSummaryView(
                            conversation: conversation,
                            onResume: {
                                Haptics.navigate()
                                onResumeConversation(conversation)
                            }
                        )
                        // iOS 18+: zoom the detail view out from the tapped row.
                        .applyZoomTransition(id: conversation.id, namespace: heroNamespace)
                    } label: {
                        ConversationRow(conversation: conversation)
                            // iOS 18+: mark this row as the transition source.
                            .applyZoomTransitionSource(id: conversation.id, namespace: heroNamespace)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                            ShareLink(
                                item: ConversationExporter.plainText(from: conversation),
                                subject: Text(conversation.displayTitle),
                                message: Text("Conversation from OpenMic")
                            ) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }

                            Button {
                                let text = ConversationExporter.plainText(from: conversation)
                                UIPasteboard.general.string = text
                                Haptics.tap()
                            } label: {
                                Label("Copy Transcript", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button(role: .destructive) {
                                conversationToDelete = conversation
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
            } // VStack(spacing: 0)
        }
        // SwiftData @Query re-evaluates automatically; a brief yield lets any
        // pending background saves flush so the list updates after the gesture.
        .customRefreshable {
            try? await Task.sleep(for: .milliseconds(400))
        }
    }

}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack(spacing: OpenMicTheme.Spacing.sm) {
                // Provider icon — tagged as the hero source by the parent NavigationLink.
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

// MARK: - Conversation Summary (push destination from History list)

/// A lightweight read-only summary pushed from ConversationListView.
/// Shows the transcript and lets the user tap "Resume" to switch to
/// the Talk tab with the conversation loaded.
private struct ConversationSummaryView: View {
    let conversation: Conversation
    let onResume: () -> Void

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.lg) {
                    // Hero header — provider icon zooms into here from the list row
                    HStack(spacing: OpenMicTheme.Spacing.md) {
                        ProviderIcon(provider: conversation.provider, size: 52)

                        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxs) {
                            Text(conversation.displayTitle)
                                .font(OpenMicTheme.Typography.title)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                .lineLimit(2)

                            Text(conversation.personaName)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                        }

                        Spacer()
                    }
                    .padding(OpenMicTheme.Spacing.md)
                    .glassBackground(cornerRadius: OpenMicTheme.Radius.lg)

                    // Message transcript
                    let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
                    ForEach(sorted) { message in
                        ConversationBubbleRow(
                            bubble: ConversationBubble(
                                role: message.messageRole,
                                text: message.content,
                                isFinal: true,
                                createdAt: message.createdAt,
                                provider: message.provider
                            ),
                            reaction: nil,
                            onReaction: { _ in },
                            onCopy: {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = message.content
                                #endif
                                Haptics.tap()
                            }
                        )
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.top, OpenMicTheme.Spacing.sm)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
            }
        }
        .navigationTitle(conversation.personaName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onResume()
                } label: {
                    Label("Resume", systemImage: "mic.fill")
                        .font(OpenMicTheme.Typography.caption.weight(.semibold))
                }
                .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                .accessibilityLabel("Resume conversation")
                .accessibilityHint("Switches to Talk tab and continues this conversation")
            }
        }
    }
}
