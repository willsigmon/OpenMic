import Foundation

/// Centralizes the BYOK / managed / keyless branching logic for creating an `AIProvider`
/// from a resolved provider type and subscription tier.
enum AIProviderResolver {

    /// Creates the appropriate `AIProvider` for the given provider type and tier.
    ///
    /// - BYOK tier: fetches the API key from the keychain (throws `invalidAPIKey` when missing).
    /// - Managed tier (cloud provider with key requirement): returns a managed proxy provider.
    /// - Keyless provider (Ollama, Apple, OpenClaw): creates directly with nil key.
    ///
    /// - Returns: A fully configured `AIProvider` ready for chat streaming.
    static func resolve(
        providerType: AIProviderType,
        tier: SubscriptionTier,
        keychainManager: KeychainManager
    ) async throws -> AIProvider {
        if tier == .byok {
            let apiKey: String?
            if providerType.requiresAPIKey {
                let stored = try? await keychainManager.getAPIKey(for: providerType)
                guard let stored, !stored.isEmpty else {
                    throw AIProviderError.invalidAPIKey
                }
                apiKey = stored
            } else {
                apiKey = nil
            }
            return try AIProviderFactory.create(type: providerType, apiKey: apiKey)
        }

        if providerType.requiresAPIKey {
            return try AIProviderFactory.createManaged(type: providerType)
        }

        return try AIProviderFactory.create(type: providerType, apiKey: nil)
    }
}
