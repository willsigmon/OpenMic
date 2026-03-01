import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .talk
    @State private var pendingPrompt: String?
    @State private var pendingConversation: Conversation?

    enum Tab: String {
        case talk, topics, history, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationView(
                initialPrompt: $pendingPrompt,
                resumeConversation: $pendingConversation
            )
                .tabItem {
                    Label("Talk", systemImage: "mic.fill")
                }
                .tag(Tab.talk)
                .accessibilityLabel("Talk")
                .accessibilityHint("Start a voice conversation")

            TopicsView { prompt in
                pendingPrompt = prompt
                selectedTab = .talk
            }
                .tabItem {
                    Label("Topics", systemImage: "sparkles.rectangle.stack")
                }
                .tag(Tab.topics)
                .accessibilityLabel("Topics")
                .accessibilityHint("Browse conversation starters")

            ConversationListView { conversation in
                pendingConversation = conversation
                selectedTab = .talk
            }
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(Tab.history)
                .accessibilityLabel("History")
                .accessibilityHint("View past conversations")

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
                .accessibilityLabel("Settings")
                .accessibilityHint("Configure app settings")
        }
        .tint(OpenMicTheme.Colors.accentGradientStart)
        .toolbarBackground(.hidden, for: .tabBar)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
