import Foundation

enum AppConstants {
    enum Defaults {
        static let personaName = "Sigmon"
        static let conversationTitle = "New Conversation"
    }

    enum UserDefaultsKeys {
        static let selectedProvider = "selectedProvider"
        static let ttsEngine = "ttsEngine"
        static let openAITTSModel = "openAITTSModel"
        static let elevenLabsModel = "elevenLabsModel"
        static let carPlaySystemPrompt = "carPlaySystemPrompt"
        static let effectiveTier = "effectiveTier"
        static let remainingMinutes = "remainingMinutes"
        static let byokMode = "byokMode"
        static let onboardingComplete = "onboardingComplete"
        static let ollamaBaseURL = "ollamaBaseURL"
        static let openclawBaseURL = "openclawBaseURL"
        static let lastWorkingProvider = "lastWorkingProvider"
        static let audioOutputMode = "audioOutputMode"
        static let deviceID = "openmic.device.id"
    }
}
