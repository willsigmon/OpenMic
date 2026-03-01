import Foundation

enum ProviderSurface: String, Sendable {
    case iPhone = "iphone"
    case carPlay = "carplay"
    case watch = "watch"
}

enum ProviderFallbackReason: String, Sendable {
    case tierRestricted
    case osUnsupported
    case providerUnavailable
    case missingConfiguration
}

struct ProviderResolutionResult: Sendable {
    let requested: AIProviderType
    let effective: AIProviderType
    let fallbackReason: ProviderFallbackReason?
    let fallbackMessage: String?

    var didFallback: Bool {
        requested != effective
    }
}

enum ProviderAccessPolicy {
    static let lastWorkingProviderKey = "lastWorkingProvider"

    private static let selectedProviderKey = "selectedProvider"
    private static let fallbackOrder: [AIProviderType] = [
        .openAI, .anthropic, .gemini, .grok, .openclaw, .ollama
    ]

    static func canShowInUI(
        provider: AIProviderType,
        tier: SubscriptionTier,
        surface: ProviderSurface,
        runtimeMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> Bool {
        evaluateRuntimeEligibility(
            provider: provider,
            tier: tier,
            runtimeMajorVersion: runtimeMajorVersion
        )
    }

    static func canUseAtRuntime(
        provider: AIProviderType,
        tier: SubscriptionTier,
        surface: ProviderSurface,
        keychainManager: KeychainManager,
        runtimeMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) async -> Bool {
        await canUseAtRuntime(
            provider: provider,
            tier: tier,
            surface: surface,
            runtimeMajorVersion: runtimeMajorVersion,
            isConfigured: { candidate in
                await hasRequiredConfiguration(
                    for: candidate,
                    keychainManager: keychainManager
                )
            },
            isRuntimeAvailable: { candidate in
                await hasRuntimeAvailability(
                    for: candidate,
                    keychainManager: keychainManager,
                    runtimeMajorVersion: runtimeMajorVersion
                )
            }
        )
    }

    static func canUseAtRuntime(
        provider: AIProviderType,
        tier: SubscriptionTier,
        surface: ProviderSurface,
        runtimeMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        isConfigured: @escaping @Sendable (AIProviderType) async -> Bool,
        isRuntimeAvailable: @escaping @Sendable (AIProviderType) async -> Bool = { _ in true }
    ) async -> Bool {
        guard evaluateRuntimeEligibility(
            provider: provider,
            tier: tier,
            runtimeMajorVersion: runtimeMajorVersion
        ) else {
            return false
        }

        guard await isRuntimeAvailable(provider) else {
            return false
        }

        return await isConfigured(provider)
    }

    static func resolveProvider(
        requested: AIProviderType,
        tier: SubscriptionTier,
        surface: ProviderSurface,
        keychainManager: KeychainManager,
        runtimeMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        useStoredFallbackHints: Bool = true
    ) async throws -> ProviderResolutionResult {
        try await resolveProvider(
            requested: requested,
            tier: tier,
            surface: surface,
            runtimeMajorVersion: runtimeMajorVersion,
            useStoredFallbackHints: useStoredFallbackHints,
            isConfigured: { candidate in
                await hasRequiredConfiguration(
                    for: candidate,
                    keychainManager: keychainManager
                )
            },
            isRuntimeAvailable: { candidate in
                await hasRuntimeAvailability(
                    for: candidate,
                    keychainManager: keychainManager,
                    runtimeMajorVersion: runtimeMajorVersion
                )
            }
        )
    }

    static func resolveProvider(
        requested: AIProviderType,
        tier: SubscriptionTier,
        surface: ProviderSurface,
        runtimeMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        useStoredFallbackHints: Bool = true,
        isConfigured: @escaping @Sendable (AIProviderType) async -> Bool,
        isRuntimeAvailable: @escaping @Sendable (AIProviderType) async -> Bool = { _ in true }
    ) async throws -> ProviderResolutionResult {
        if await canUseAtRuntime(
            provider: requested,
            tier: tier,
            surface: surface,
            runtimeMajorVersion: runtimeMajorVersion,
            isConfigured: isConfigured,
            isRuntimeAvailable: isRuntimeAvailable
        ) {
            return ProviderResolutionResult(
                requested: requested,
                effective: requested,
                fallbackReason: nil,
                fallbackMessage: nil
            )
        }

        let reason = await fallbackReason(
            for: requested,
            tier: tier,
            runtimeMajorVersion: runtimeMajorVersion,
            isConfigured: isConfigured,
            isRuntimeAvailable: isRuntimeAvailable
        )

        guard let fallback = await firstFallbackCandidate(
            excluding: requested,
            tier: tier,
            surface: surface,
            runtimeMajorVersion: runtimeMajorVersion,
            useStoredFallbackHints: useStoredFallbackHints,
            isConfigured: isConfigured,
            isRuntimeAvailable: isRuntimeAvailable
        ) else {
            throw AIProviderError.configurationMissing(
                "No configured providers are available right now"
            )
        }

        return ProviderResolutionResult(
            requested: requested,
            effective: fallback,
            fallbackReason: reason,
            fallbackMessage: fallbackMessage(
                requested: requested,
                effective: fallback,
                reason: reason
            )
        )
    }

    static func markProviderAsWorking(_ provider: AIProviderType) {
        UserDefaults.standard.set(provider.rawValue, forKey: lastWorkingProviderKey)
    }

    static func lastWorkingProvider() -> AIProviderType? {
        guard let raw = UserDefaults.standard.string(forKey: lastWorkingProviderKey) else {
            return nil
        }
        return AIProviderType(rawValue: raw)
    }

    private static func evaluateRuntimeEligibility(
        provider: AIProviderType,
        tier: SubscriptionTier,
        runtimeMajorVersion: Int
    ) -> Bool {
        guard provider.isAvailable else { return false }
        guard provider.isAllowedForTier(tier) else { return false }
        guard provider.isRuntimeAvailable(onMajorVersion: runtimeMajorVersion) else {
            return false
        }
        return true
    }

    private static func firstFallbackCandidate(
        excluding requested: AIProviderType,
        tier: SubscriptionTier,
        surface: ProviderSurface,
        runtimeMajorVersion: Int,
        useStoredFallbackHints: Bool,
        isConfigured: @escaping @Sendable (AIProviderType) async -> Bool,
        isRuntimeAvailable: @escaping @Sendable (AIProviderType) async -> Bool
    ) async -> AIProviderType? {
        var candidates: [AIProviderType] = []

        if useStoredFallbackHints {
            if let last = lastWorkingProvider() {
                candidates.append(last)
            }

            if let selected = selectedProviderFromDefaults(),
               selected != .apple {
                candidates.append(selected)
            }
        }

        candidates.append(contentsOf: fallbackOrder)

        var seen: Set<AIProviderType> = []
        for candidate in candidates where candidate != requested {
            if seen.contains(candidate) {
                continue
            }
            seen.insert(candidate)

            if await canUseAtRuntime(
                provider: candidate,
                tier: tier,
                surface: surface,
                runtimeMajorVersion: runtimeMajorVersion,
                isConfigured: isConfigured,
                isRuntimeAvailable: isRuntimeAvailable
            ) {
                return candidate
            }
        }

        return nil
    }

    private static func fallbackReason(
        for provider: AIProviderType,
        tier: SubscriptionTier,
        runtimeMajorVersion: Int,
        isConfigured: @escaping @Sendable (AIProviderType) async -> Bool,
        isRuntimeAvailable: @escaping @Sendable (AIProviderType) async -> Bool
    ) async -> ProviderFallbackReason {
        if !provider.isAllowedForTier(tier) {
            return .tierRestricted
        }

        if !provider.isRuntimeAvailable(onMajorVersion: runtimeMajorVersion) {
            return .osUnsupported
        }

        if !provider.isAvailable {
            return .providerUnavailable
        }

        if !(await isRuntimeAvailable(provider)) {
            return .providerUnavailable
        }

        if !(await isConfigured(provider)) {
            return .missingConfiguration
        }

        return .providerUnavailable
    }

    private static func fallbackMessage(
        requested: AIProviderType,
        effective: AIProviderType,
        reason: ProviderFallbackReason
    ) -> String {
        switch reason {
        case .tierRestricted:
            return "\(requested.displayName) needs Premium or BYOK. Using \(effective.displayName)."
        case .osUnsupported:
            return "\(requested.displayName) needs iOS 26 or later. Using \(effective.displayName)."
        case .providerUnavailable:
            return "\(requested.displayName) is unavailable right now. Using \(effective.displayName). You can switch providers in Settings."
        case .missingConfiguration:
            return "\(requested.displayName) is not configured. Using \(effective.displayName). Add or update your key in Settings."
        }
    }

    private static func hasRequiredConfiguration(
        for provider: AIProviderType,
        keychainManager: KeychainManager
    ) async -> Bool {
        if provider == .openclaw {
            guard let baseURL = UserDefaults.standard.string(forKey: "openclawBaseURL") else {
                return false
            }
            return !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if provider.requiresAPIKey {
            return (try? await keychainManager.hasAPIKey(for: provider)) == true
        }

        return true
    }

    private static func hasRuntimeAvailability(
        for provider: AIProviderType,
        keychainManager: KeychainManager,
        runtimeMajorVersion: Int
    ) async -> Bool {
        switch provider {
        case .apple:
            do {
                let runtimeProvider = try AIProviderFactory.create(
                    type: .apple,
                    apiKey: nil,
                    runtimeMajorVersion: runtimeMajorVersion
                )
                return (try? await runtimeProvider.validateKey()) == true
            } catch {
                return false
            }
        default:
            _ = keychainManager
            return true
        }
    }

    private static func selectedProviderFromDefaults() -> AIProviderType? {
        guard let raw = UserDefaults.standard.string(forKey: selectedProviderKey) else {
            return nil
        }
        return AIProviderType(rawValue: raw)
    }
}
