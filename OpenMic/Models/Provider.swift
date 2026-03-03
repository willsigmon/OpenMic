import Foundation

enum AIProviderType: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    case grok = "grok"
    case apple = "apple"
    case ollama = "ollama"
    case openclaw = "openclaw"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Google Gemini"
        case .grok: "xAI Grok"
        case .apple: "Apple Intelligence"
        case .ollama: "Ollama"
        case .openclaw: "OpenClaw (Marlin)"
        }
    }

    /// Compact name for small chips and badges
    var shortName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Claude"
        case .gemini: "Gemini"
        case .grok: "Grok"
        case .apple: "Apple"
        case .ollama: "Ollama"
        case .openclaw: "Marlin"
        }
    }

    /// Short, fun tagline for the provider card
    var tagline: String {
        switch self {
        case .openAI: "The OG. GPT-4o and friends."
        case .anthropic: "Claude thinks before it speaks."
        case .gemini: "Google's multimodal brainchild."
        case .grok: "Unfiltered. Built by xAI."
        case .apple: "Private. On-device. Just works."
        case .ollama: "Run your own models on your own server."
        case .openclaw: "Your personal AI agent. Self-hosted."
        }
    }

    /// The default model for each provider
    var defaultModel: String {
        switch self {
        case .openAI: "gpt-4o"
        case .anthropic: "claude-sonnet-4-5-20250214"
        case .gemini: "gemini-2.0-flash"
        case .grok: "grok-2"
        case .apple: "apple-foundation"
        case .ollama: "llama3.2"
        case .openclaw: "gemini-2.0-flash"
        }
    }

    /// Whether this provider is fully implemented and available for use
    var isAvailable: Bool {
        switch self {
        case .apple:
            #if canImport(FoundationModels)
            true
            #else
            false
            #endif
        case .openAI, .anthropic, .gemini, .grok, .ollama, .openclaw:
            true
        }
    }

    /// Minimum OS major version needed for runtime usage.
    var minimumSupportedOSMajorVersion: Int? {
        switch self {
        case .apple:
            26
        default:
            nil
        }
    }

    /// Runtime availability on the current operating system.
    var isRuntimeAvailable: Bool {
        isRuntimeAvailable(
            onMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }

    func isRuntimeAvailable(onMajorVersion majorVersion: Int) -> Bool {
        guard isAvailable else { return false }
        guard let minimum = minimumSupportedOSMajorVersion else { return true }
        return majorVersion >= minimum
    }

    /// Tier gating for providers with explicit plan requirements.
    func isAllowedForTier(_ tier: SubscriptionTier) -> Bool {
        switch self {
        case .apple:
            return tier == .premium || tier == .byok
        default:
            return true
        }
    }

    var supportsRealtimeVoice: Bool {
        switch self {
        case .openAI, .gemini: true
        case .anthropic, .grok, .apple, .ollama, .openclaw: false
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama, .apple, .openclaw: false
        default: true
        }
    }

    /// Whether this provider runs on-device (no network needed)
    var isLocal: Bool {
        switch self {
        case .apple: true
        case .openclaw: false
        case .ollama: false
        default: false
        }
    }

    var baseURL: String? {
        switch self {
        case .grok: "https://api.x.ai/v1"
        case .ollama:
            UserDefaults.standard.string(forKey: "ollamaBaseURL")
        case .openclaw:
            UserDefaults.standard.string(forKey: "openclawBaseURL")
        default: nil
        }
    }

    var keychainKey: String {
        "openmic.apikey.\(rawValue)"
    }

    var apiKeyPortalURL: URL? {
        switch self {
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")
        case .gemini:
            return URL(string: "https://ai.google.dev/gemini-api/docs/api-key")
        case .grok:
            return URL(string: "https://console.x.ai")
        case .apple, .ollama, .openclaw:
            return nil
        }
    }

    var apiKeyHelpText: String? {
        guard requiresAPIKey else { return nil }
        return "Need a key? Sign in to \(displayName) and create one."
    }

    /// Whether this provider is self-hosted (needs network but not a commercial API key)
    var isSelfHosted: Bool {
        switch self {
        case .openclaw, .ollama: true
        default: false
        }
    }

    /// Cloud providers that need API keys
    static var cloudProviders: [AIProviderType] {
        allCases.filter { $0.requiresAPIKey }
    }

    /// Local/on-device providers
    static var localProviders: [AIProviderType] {
        allCases.filter { $0.isLocal }
    }

    /// Self-hosted providers (separate section in settings)
    static var selfHostedProviders: [AIProviderType] {
        allCases.filter { $0.isSelfHosted }
    }
}
