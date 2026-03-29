import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .talk
    @State private var pendingPrompt: String?
    @State private var pendingConversation: Conversation?
    @State private var launchVoice = false
    @AppStorage("hasSeenNotificationAsk") private var hasSeenNotificationAsk = false
    @AppStorage("hasSeenSpotlight") private var hasSeenSpotlight = false
    @State private var showNotificationPermission = false
    @Environment(\.spotlightCoordinator) private var spotlightCoordinator

    enum Tab: String {
        case talk, topics, history, settings
    }

    // Tab bar items are static — all state-awareness is passed via parameters
    private static let tabItems: [OpenMicTabItem] = [
        OpenMicTabItem(id: .talk,     icon: "mic",                      title: "Talk",     isSpecial: true),
        OpenMicTabItem(id: .topics,   icon: "sparkles.rectangle.stack", title: "Topics"),
        OpenMicTabItem(id: .history,  icon: "clock",                    title: "History"),
        OpenMicTabItem(id: .settings, icon: "gearshape",                title: "Settings")
    ]

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationView(
                initialPrompt: $pendingPrompt,
                resumeConversation: $pendingConversation,
                autoStartVoice: $launchVoice
            )
                .tabItem {
                    Label("Talk", systemImage: "mic.fill")
                }
                .tag(Tab.talk)
                .accessibilityLabel("Talk")
                .accessibilityHint("Start a voice conversation")
                .spotlightTarget(.micButton)

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
                .spotlightTarget(.topicsTab)

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
                .spotlightTarget(.settingsTab)
        }
        .tint(OpenMicTheme.Colors.accentGradientStart)
        // Hide native tab bar — OpenMicAnimatedTabBar renders below
        .toolbar(.hidden, for: .tabBar)
        // Custom animated tab bar
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OpenMicAnimatedTabBar(
                selection: $selectedTab,
                tabs: Self.tabItems,
                micState: .idle  // Wire to VoiceSession state at the call site when available
            )
        }
        .toastOverlay()
        .onOpenURL { url in
            handleDeepLink(url)
        }
        // Notification permission pre-ask shown once after onboarding
        .sheet(isPresented: $showNotificationPermission) {
            NotificationPermissionView()
        }
        .task {
            guard !hasSeenNotificationAsk else { return }
            // Small delay so the main UI is visible before the sheet appears
            try? await Task.sleep(for: .milliseconds(1200))
            showNotificationPermission = true
        }
        // Spotlight tour: shown once after onboarding completes
        .task {
            guard !hasSeenSpotlight else { return }
            try? await Task.sleep(for: .milliseconds(800))
            hasSeenSpotlight = true
            spotlightCoordinator?.startTour(.firstRun)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "openmic" else { return }
        switch url.host {
        case "voice", "talk":
            selectedTab = .talk
            launchVoice = true
        case "history":
            selectedTab = .history
        case "settings":
            selectedTab = .settings
        case "topics":
            selectedTab = .topics
        default:
            selectedTab = .talk
        }
    }
}
