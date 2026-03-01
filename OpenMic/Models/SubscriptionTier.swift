import Foundation

enum SubscriptionTier: String, Codable, Sendable, CaseIterable, Identifiable {
    case free
    case standard
    case premium
    case byok

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: "Free"
        case .standard: "Standard"
        case .premium: "Premium"
        case .byok: "Power User"
        }
    }

    var monthlyMinutes: Int {
        switch self {
        case .free: 10
        case .standard: 120
        case .premium: 120
        case .byok: .max
        }
    }

    var maxSessionMinutes: Int {
        switch self {
        case .free: 5
        case .standard: 30
        case .premium: 60
        case .byok: .max
        }
    }

    var monthlyPriceCents: Int {
        switch self {
        case .free: 0
        case .standard: 999
        case .premium: 2499
        case .byok: 0
        }
    }

    var availableProviders: [AIProviderType] {
        switch self {
        case .free:
            [.openAI]
        case .standard:
            [.openAI, .anthropic, .gemini, .grok]
        case .premium:
            AIProviderType.allCases.filter { $0.isAvailable }
        case .byok:
            AIProviderType.allCases
        }
    }

    var supportsRealtime: Bool {
        switch self {
        case .free, .standard: false
        case .premium, .byok: true
        }
    }

    var voiceQualityDescription: String {
        switch self {
        case .free: "System TTS + GPT-4o-mini"
        case .standard: "OpenAI TTS / Cartesia"
        case .premium: "OpenAI Realtime / Gemini Live / Hume EVI 3"
        case .byok: "Your own API keys — unlimited"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            [
                "10 minutes/month",
                "System voice (on-device)",
                "GPT-4o-mini responses",
                "Basic conversation history",
            ]
        case .standard:
            [
                "120 minutes/month",
                "Premium TTS voices",
                "GPT-4o / Claude / Gemini",
                "Full conversation history",
                "Custom personas",
            ]
        case .premium:
            [
                "120 minutes/month",
                "Realtime voice AI",
                "All providers included",
                "Emotional intelligence (Hume)",
                "Priority support",
            ]
        case .byok:
            [
                "Unlimited usage",
                "Your own API keys",
                "All providers",
                "Full customization",
            ]
        }
    }
}
