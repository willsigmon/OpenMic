import Foundation

enum AIProviderFactory {
    private static func normalizedEndpoint(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let withScheme: String
        if trimmed.contains("://") {
            withScheme = trimmed
        } else {
            withScheme = "http://\(trimmed)"
        }

        return withScheme.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

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
            guard let baseURL = UserDefaults.standard.string(forKey: "ollamaBaseURL"),
                  !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIProviderError.configurationMissing("Ollama base URL not configured")
            }
            return OllamaProvider(
                baseURL: normalizedEndpoint(baseURL),
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
                baseURL: normalizedEndpoint(baseURL),
                model: model ?? type.defaultModel
            )
        }
    }

    static func createManaged(
        type: AIProviderType,
        model: String? = nil,
        endpointURL: URL? = SupabaseConfig.managedChatFunctionURL,
        authTokenProvider: @escaping @Sendable () async throws -> String = {
            try await ManagedSessionTokenProvider.accessToken()
        }
    ) throws -> AIProvider {
        guard let endpointURL else {
            throw AIProviderError.configurationMissing("Supabase managed chat URL not configured")
        }
        return ManagedProxyProvider(
            providerType: type,
            endpointURL: endpointURL,
            model: model ?? type.defaultModel,
            authTokenProvider: authTokenProvider
        )
    }
}
