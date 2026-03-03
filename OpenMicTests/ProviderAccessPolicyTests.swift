import Testing
import Foundation
@testable import OpenMic

@Suite("Provider Access Policy")
struct ProviderAccessPolicyTests {
    @Test("Apple provider UI gating uses tier and OS")
    func appleUIVisibility() {
        if AIProviderType.apple.isAvailable {
            #expect(
                ProviderAccessPolicy.canShowInUI(
                    provider: .apple,
                    tier: .premium,
                    surface: .iPhone,
                    runtimeMajorVersion: 26
                )
            )
            #expect(
                !ProviderAccessPolicy.canShowInUI(
                    provider: .apple,
                    tier: .standard,
                    surface: .iPhone,
                    runtimeMajorVersion: 26
                )
            )
            #expect(
                !ProviderAccessPolicy.canShowInUI(
                    provider: .apple,
                    tier: .premium,
                    surface: .iPhone,
                    runtimeMajorVersion: 18
                )
            )
        } else {
            #expect(
                !ProviderAccessPolicy.canShowInUI(
                    provider: .apple,
                    tier: .premium,
                    surface: .iPhone,
                    runtimeMajorVersion: 26
                )
            )
        }
    }

    @Test("Apple runtime gating enforces eligibility")
    func appleRuntimeEligibility() async {
        let allowed = await ProviderAccessPolicy.canUseAtRuntime(
            provider: .apple,
            tier: .premium,
            surface: .iPhone,
            runtimeMajorVersion: 26,
            isConfigured: { _ in true }
        )
        #expect(allowed == AIProviderType.apple.isAvailable)

        let deniedByTier = await ProviderAccessPolicy.canUseAtRuntime(
            provider: .apple,
            tier: .free,
            surface: .iPhone,
            runtimeMajorVersion: 26,
            isConfigured: { _ in true }
        )
        #expect(!deniedByTier)

        let deniedByOS = await ProviderAccessPolicy.canUseAtRuntime(
            provider: .apple,
            tier: .premium,
            surface: .iPhone,
            runtimeMajorVersion: 18,
            isConfigured: { _ in true }
        )
        #expect(!deniedByOS)
    }

    @Test("AIProviderFactory gates Apple by runtime policy")
    func appleFactoryRuntimeGate() {
        do {
            _ = try AIProviderFactory.create(
                type: .apple,
                apiKey: nil,
                runtimeMajorVersion: 18
            )
            #expect(Bool(false))
        } catch let error as AIProviderError {
            if case .configurationMissing = error {
                #expect(true)
            } else {
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }

        if AIProviderType.apple.isAvailable {
            do {
                let provider = try AIProviderFactory.create(
                    type: .apple,
                    apiKey: nil,
                    runtimeMajorVersion: 26
                )
                #expect(provider.providerType == .apple)
            } catch {
                #expect(Bool(false))
            }
        }
    }

    @Test("Fallback skips missing configuration in fallback chain")
    func fallbackSkipsMissingConfiguration() async throws {
        let result = try await ProviderAccessPolicy.resolveProvider(
            requested: .apple,
            tier: .premium,
            surface: .iPhone,
            runtimeMajorVersion: 18,
            useStoredFallbackHints: false,
            isConfigured: { provider in
                switch provider {
                case .openAI, .anthropic:
                    return false
                case .gemini:
                    return true
                default:
                    return false
                }
            },
            isRuntimeAvailable: { _ in true }
        )

        #expect(result.didFallback)
        #expect(result.effective == .gemini)
        #expect(result.fallbackReason == .osUnsupported)
    }

    @Test("Fallback when requested provider is runtime unavailable")
    func fallbackWhenRuntimeUnavailable() async throws {
        let result = try await ProviderAccessPolicy.resolveProvider(
            requested: .apple,
            tier: .premium,
            surface: .iPhone,
            runtimeMajorVersion: 26,
            useStoredFallbackHints: false,
            isConfigured: { provider in
                provider == .openAI || provider == .apple
            },
            isRuntimeAvailable: { provider in
                provider != .apple
            }
        )

        #expect(result.didFallback)
        #expect(result.effective == .openAI)
        #expect(result.fallbackReason == .providerUnavailable)
    }

    @Test("Last working provider is preferred for fallback")
    func lastWorkingProviderPreference() async throws {
        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: ProviderAccessPolicy.lastWorkingProviderKey)
        defaults.set(AIProviderType.grok.rawValue, forKey: ProviderAccessPolicy.lastWorkingProviderKey)

        defer {
            if let original {
                defaults.set(original, forKey: ProviderAccessPolicy.lastWorkingProviderKey)
            } else {
                defaults.removeObject(forKey: ProviderAccessPolicy.lastWorkingProviderKey)
            }
        }

        let result = try await ProviderAccessPolicy.resolveProvider(
            requested: .apple,
            tier: .premium,
            surface: .iPhone,
            runtimeMajorVersion: 18,
            useStoredFallbackHints: true,
            isConfigured: { provider in
                provider == .grok
            },
            isRuntimeAvailable: { _ in true }
        )

        #expect(result.didFallback)
        #expect(result.effective == .grok)
        #expect(result.fallbackReason == .osUnsupported)
    }

    @Test("canUseAtRuntime checks runtime availability callback")
    func canUseAtRuntimeChecksRuntimeAvailability() async {
        let result = await ProviderAccessPolicy.canUseAtRuntime(
            provider: .apple,
            tier: .premium,
            surface: .iPhone,
            runtimeMajorVersion: 26,
            isConfigured: { _ in true },
            isRuntimeAvailable: { _ in false }
        )

        #expect(!result)
    }

    @Test("canUseAtRuntime still works when runtime availability is true")
    func canUseAtRuntimeWhenRuntimeAvailable() async {
        let result = await ProviderAccessPolicy.canUseAtRuntime(
            provider: .openAI,
            tier: .premium,
            surface: .iPhone,
            runtimeMajorVersion: 26,
            isConfigured: { provider in
                provider == .openAI
            }
        )

        #expect(result)
    }

    @Test("Managed tiers do not require cloud API keys")
    func managedTierDoesNotRequireCloudKey() async {
        let keychainManager = KeychainManager(
            service: "com.willsigmon.openmic.tests.managed.\(UUID().uuidString)"
        )

        let result = await ProviderAccessPolicy.canUseAtRuntime(
            provider: .openAI,
            tier: .free,
            surface: .iPhone,
            keychainManager: keychainManager
        )

        #expect(result)
    }

    @Test("BYOK tier still requires cloud API keys")
    func byokTierStillRequiresCloudKey() async {
        let keychainManager = KeychainManager(
            service: "com.willsigmon.openmic.tests.byok.\(UUID().uuidString)"
        )

        let result = await ProviderAccessPolicy.canUseAtRuntime(
            provider: .openAI,
            tier: .byok,
            surface: .iPhone,
            keychainManager: keychainManager
        )

        #expect(!result)
    }
}
