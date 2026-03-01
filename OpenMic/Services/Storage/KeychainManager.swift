import Foundation
import KeychainAccess

actor KeychainManager {
    private let keychain: Keychain

    init(service: String = "com.willsigmon.openmic") {
        self.keychain = Keychain(service: service)
            .accessibility(.afterFirstUnlock)
    }

    // MARK: - Core Operations

    func save(key: String, value: String) throws {
        try keychain.set(value, key: key)
    }

    func get(key: String) throws -> String? {
        try keychain.get(key)
    }

    func delete(key: String) throws {
        try keychain.remove(key)
    }

    // MARK: - AI Provider Keys

    func saveAPIKey(for provider: AIProviderType, key: String) throws {
        try save(key: provider.keychainKey, value: key)
    }

    func getAPIKey(for provider: AIProviderType) throws -> String? {
        try get(key: provider.keychainKey)
    }

    func deleteAPIKey(for provider: AIProviderType) throws {
        try delete(key: provider.keychainKey)
    }

    func hasAPIKey(for provider: AIProviderType) throws -> Bool {
        guard let key = try get(key: provider.keychainKey) else { return false }
        return !key.isEmpty
    }

    // MARK: - Generic TTS Engine Keys

    func saveTTSKey(for engine: TTSEngineType, key: String) throws {
        try save(key: engine.keychainKey, value: key)
    }

    func getTTSKey(for engine: TTSEngineType) throws -> String? {
        try get(key: engine.keychainKey)
    }

    func deleteTTSKey(for engine: TTSEngineType) throws {
        try delete(key: engine.keychainKey)
        if let secondary = engine.secondaryKeychainKey {
            try delete(key: secondary)
        }
    }

    func hasTTSKey(for engine: TTSEngineType) throws -> Bool {
        guard let key = try get(key: engine.keychainKey) else { return false }
        if key.isEmpty { return false }
        if let secondary = engine.secondaryKeychainKey {
            guard let secret = try get(key: secondary) else { return false }
            return !secret.isEmpty
        }
        return true
    }

    /// Save the secondary key for engines that need two keys (e.g. Amazon Polly secret key)
    func saveTTSSecondaryKey(for engine: TTSEngineType, key: String) throws {
        guard let secondary = engine.secondaryKeychainKey else { return }
        try save(key: secondary, value: key)
    }

    func getTTSSecondaryKey(for engine: TTSEngineType) throws -> String? {
        guard let secondary = engine.secondaryKeychainKey else { return nil }
        return try get(key: secondary)
    }

    // MARK: - Legacy Per-Engine Methods (forwards to generic)

    func saveElevenLabsKey(_ key: String) throws { try saveTTSKey(for: .elevenLabs, key: key) }
    func getElevenLabsKey() throws -> String? { try getTTSKey(for: .elevenLabs) }
    func deleteElevenLabsKey() throws { try deleteTTSKey(for: .elevenLabs) }
    func hasElevenLabsKey() throws -> Bool { try hasTTSKey(for: .elevenLabs) }

    func saveHumeAIKey(_ key: String) throws { try saveTTSKey(for: .humeAI, key: key) }
    func getHumeAIKey() throws -> String? { try getTTSKey(for: .humeAI) }
    func deleteHumeAIKey() throws { try deleteTTSKey(for: .humeAI) }
    func hasHumeAIKey() throws -> Bool { try hasTTSKey(for: .humeAI) }

    func saveGoogleCloudKey(_ key: String) throws { try saveTTSKey(for: .googleCloud, key: key) }
    func getGoogleCloudKey() throws -> String? { try getTTSKey(for: .googleCloud) }
    func deleteGoogleCloudKey() throws { try deleteTTSKey(for: .googleCloud) }
    func hasGoogleCloudKey() throws -> Bool { try hasTTSKey(for: .googleCloud) }

    func saveCartesiaKey(_ key: String) throws { try saveTTSKey(for: .cartesia, key: key) }
    func getCartesiaKey() throws -> String? { try getTTSKey(for: .cartesia) }
    func deleteCartesiaKey() throws { try deleteTTSKey(for: .cartesia) }
    func hasCartesiaKey() throws -> Bool { try hasTTSKey(for: .cartesia) }

    func saveAmazonPollyKeys(accessKey: String, secretKey: String) throws {
        try saveTTSKey(for: .amazonPolly, key: accessKey)
        try saveTTSSecondaryKey(for: .amazonPolly, key: secretKey)
    }
    func getAmazonPollyAccessKey() throws -> String? { try getTTSKey(for: .amazonPolly) }
    func getAmazonPollySecretKey() throws -> String? { try getTTSSecondaryKey(for: .amazonPolly) }
    func deleteAmazonPollyKeys() throws { try deleteTTSKey(for: .amazonPolly) }
    func hasAmazonPollyKeys() throws -> Bool { try hasTTSKey(for: .amazonPolly) }

    func saveDeepgramKey(_ key: String) throws { try saveTTSKey(for: .deepgram, key: key) }
    func getDeepgramKey() throws -> String? { try getTTSKey(for: .deepgram) }
    func deleteDeepgramKey() throws { try deleteTTSKey(for: .deepgram) }
    func hasDeepgramKey() throws -> Bool { try hasTTSKey(for: .deepgram) }
}
