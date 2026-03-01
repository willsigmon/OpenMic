import Foundation

enum AIProviderFactory {
    static func create(
        type: AIProviderType,
        apiKey: String?,
        model: String? = nil,
        runtimeMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) throws -> AIProvider {
        switch type {
        case .openAI:
            guard let apiKey, !apiKey.isEmpty else {
                throw AIProviderError.invalidAPIKey
            }
            return OpenAIProvider(
                apiKey: apiKey,
                model: model ?? type.defaultModel
            )

        case .anthropic:
            guard let apiKey, !apiKey.isEmpty else {
                throw AIProviderError.invalidAPIKey
            }
            return AnthropicProvider(
                apiKey: apiKey,
                model: model ?? type.defaultModel
            )

        case .gemini:
            guard let apiKey, !apiKey.isEmpty else {
                throw AIProviderError.invalidAPIKey
            }
            return GeminiProvider(
                apiKey: apiKey,
                model: model ?? type.defaultModel
            )

        case .grok:
            guard let apiKey, !apiKey.isEmpty else {
                throw AIProviderError.invalidAPIKey
            }
            return GrokProvider(
                apiKey: apiKey,
                model: model ?? type.defaultModel
            )

        case .ollama:
            return OllamaProvider(
                model: model ?? type.defaultModel
            )

        case .apple:
            #if canImport(FoundationModels)
            guard AIProviderType.apple.isRuntimeAvailable(onMajorVersion: runtimeMajorVersion) else {
                throw AIProviderError.configurationMissing("Apple Intelligence requires iOS 26 or later")
            }
            return AppleFoundationModelsProvider()
            #else
            throw AIProviderError.configurationMissing("Apple Intelligence is not available in this build")
            #endif

        case .openclaw:
            guard let baseURL = UserDefaults.standard.string(forKey: "openclawBaseURL"),
                  !baseURL.isEmpty else {
                throw AIProviderError.configurationMissing("OpenClaw base URL not configured")
            }
            return OpenClawProvider(
                apiKey: apiKey ?? "",
                baseURL: baseURL,
                model: model ?? type.defaultModel
            )
        }
    }
}
