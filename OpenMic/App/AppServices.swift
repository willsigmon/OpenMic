import SwiftUI
import SwiftData
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "AppServices")

@Observable
@MainActor
final class AppServices {
    let modelContainer: ModelContainer
    let keychainManager: KeychainManager
    let conversationStore: ConversationStore
    let watchConnectivityManager: WatchConnectivityManager
    let authManager: AuthManager
    let storeManager: StoreManager
    let usageTracker: UsageTracker
    let notificationManager: NotificationManager

    private(set) var isOnboardingComplete: Bool
    /// True when SwiftData failed to open the persistent store and fell back to in-memory storage.
    /// Data will NOT survive an app restart in this state.
    private(set) var isUsingInMemoryFallback: Bool = false

    /// The effective subscription tier considering auth state and StoreKit
    var effectiveTier: SubscriptionTier {
        if authManager.authState.isBYOK {
            return .byok
        }
        return storeManager.currentTier
    }

    init() {
        let schema = Schema([
            Conversation.self,
            Message.self,
            Persona.self
        ])

        let container: ModelContainer
        var inMemoryFallback = false
        do {
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch let persistentError {
            // Fallback to in-memory if persistent store fails (corrupted DB, etc.)
            log.fault("SwiftData persistent store failed — falling back to in-memory storage. Data will NOT be persisted. Error: \(persistentError.localizedDescription, privacy: .public)")
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                container = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfig]
                )
                inMemoryFallback = true
            } catch {
                fatalError("OpenMic: Failed to create even in-memory ModelContainer: \(error)")
            }
        }

        self.modelContainer = container
        self.keychainManager = KeychainManager()
        self.conversationStore = ConversationStore(
            modelContainer: container
        )
        self.watchConnectivityManager = WatchConnectivityManager(
            keychainManager: self.keychainManager
        )
        self.authManager = AuthManager()
        self.storeManager = StoreManager()
        self.usageTracker = UsageTracker()
        self.notificationManager = NotificationManager()
        self.usageTracker.notificationManager = self.notificationManager
        self.isOnboardingComplete = UserDefaults.standard.bool(
            forKey: "onboardingComplete"
        )
        self.isUsingInMemoryFallback = inMemoryFallback
    }

    func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }

    /// Called on app launch to restore auth session and load products
    func bootstrap() async {
        await authManager.restoreSession()
        await storeManager.loadProducts()
        await usageTracker.refreshQuota(tier: effectiveTier)
        await notificationManager.checkAuthorizationStatus()
        notificationManager.registerCategories()
        syncTierToWatch()
    }

    func handleAccountDeletionCleanup() async {
        conversationStore.deleteAllConversations()
        usageTracker.resetToFreeDefaults()

        do {
            try await keychainManager.clearStoredCredentials()
        } catch {
            // Best effort cleanup
        }

        UserDefaults.standard.removeObject(forKey: "byokMode")
        syncTierToWatch()
    }

    /// Sync subscription tier to Watch and UserDefaults (for CarPlay scene)
    func syncTierToWatch() {
        let tier = effectiveTier
        watchConnectivityManager.sendTierUpdate(
            tier: tier,
            remainingMinutes: usageTracker.remainingMinutes
        )
        // CarPlay scene delegate reads from UserDefaults since it lacks AppServices access
        UserDefaults.standard.set(tier.rawValue, forKey: "effectiveTier")
        UserDefaults.standard.set(usageTracker.remainingMinutes, forKey: "remainingMinutes")

        // Mirror active persona's system prompt for CarPlay (no SwiftData access in CarPlay scene)
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Persona>(
            predicate: #Predicate { $0.isDefault == true }
        )
        if let persona = (try? context.fetch(descriptor))?.first {
            UserDefaults.standard.set(persona.systemPrompt, forKey: "carPlaySystemPrompt")
        }
    }

    func seedDefaultPersonaIfNeeded() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Persona>(
            predicate: #Predicate { $0.isDefault == true }
        )

        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        guard let url = Bundle.main.url(
            forResource: "SigmonPersona",
            withExtension: "json"
        ),
        let data = try? Data(contentsOf: url),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let persona = Persona(
            name: json["name"] as? String ?? "Sigmon",
            personality: json["personality"] as? String ?? "",
            systemPrompt: json["systemPrompt"] as? String ?? "",
            isDefault: true,
            openAIRealtimeVoice: json["openAIRealtimeVoice"] as? String ?? "alloy",
            geminiVoice: json["geminiVoice"] as? String ?? "Kore",
            elevenLabsVoiceID: json["elevenLabsVoiceID"] as? String,
            systemTTSVoice: json["systemTTSVoice"] as? String
        )

        context.insert(persona)
        try? context.save()
    }
}
