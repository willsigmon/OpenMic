import Foundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "HumeAI")

// MARK: - Hume AI Voice

struct HumeAIVoice: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
    }
}

// MARK: - Voice Manager

/// Fetches and caches available Hume AI voices.
actor HumeAIVoiceManager {
    private var cachedVoices: [HumeAIVoice] = []
    private var cacheTime: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes

    func voices(apiKey: String) async throws -> [HumeAIVoice] {
        if let cached = cacheTime, Date().timeIntervalSince(cached) < cacheDuration, !cachedVoices.isEmpty {
            return cachedVoices
        }

        guard let url = URL(string: "https://api.hume.ai/v0/tts/voices") else {
            throw HumeAIError.voiceFetchFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "X-Hume-Api-Key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HumeAIError.voiceFetchFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw HumeAIError.invalidAPIKey
            }
            throw HumeAIError.voiceFetchFailed
        }

        let decoded = try JSONDecoder().decode([HumeAIVoice].self, from: data)
        cachedVoices = decoded
        cacheTime = Date()
        return decoded
    }

    func clearCache() {
        cachedVoices = []
        cacheTime = nil
    }
}

// MARK: - Errors

enum HumeAIError: LocalizedError {
    case synthesizeFailed
    case invalidAPIKey
    case apiKeyMissing
    case rateLimited
    case emptyResponse
    case voiceFetchFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .synthesizeFailed: "Hume AI synthesis failed"
        case .invalidAPIKey: "Invalid Hume AI API key"
        case .apiKeyMissing: "Hume AI API key not configured"
        case .rateLimited: "Hume AI rate limit reached — wait a moment"
        case .emptyResponse: "Hume AI returned empty audio data"
        case .voiceFetchFailed: "Failed to fetch Hume AI voices"
        case .networkError(let msg): "Hume AI: \(msg)"
        }
    }
}
