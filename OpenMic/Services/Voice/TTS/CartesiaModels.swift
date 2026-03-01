import Foundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "Cartesia")

// MARK: - Cartesia Voice

struct CartesiaVoice: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let language: String?

    var displayName: String { name }
}

// MARK: - Voice Manager

actor CartesiaVoiceManager {
    private var cachedVoices: [CartesiaVoice] = []
    private var cacheTime: Date?
    private let cacheDuration: TimeInterval = 300

    func voices(apiKey: String) async throws -> [CartesiaVoice] {
        if let cached = cacheTime, Date().timeIntervalSince(cached) < cacheDuration, !cachedVoices.isEmpty {
            return cachedVoices
        }

        guard let url = URL(string: "https://api.cartesia.ai/voices") else {
            throw CartesiaTTSError.voiceFetchFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("2024-06-10", forHTTPHeaderField: "Cartesia-Version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CartesiaTTSError.voiceFetchFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CartesiaTTSError.invalidAPIKey
            }
            throw CartesiaTTSError.voiceFetchFailed
        }

        let decoded = try JSONDecoder().decode([CartesiaVoice].self, from: data)
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

enum CartesiaTTSError: LocalizedError {
    case synthesizeFailed
    case invalidAPIKey
    case apiKeyMissing
    case rateLimited
    case emptyResponse
    case voiceFetchFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .synthesizeFailed: "Cartesia synthesis failed"
        case .invalidAPIKey: "Invalid Cartesia API key"
        case .apiKeyMissing: "Cartesia API key not configured"
        case .rateLimited: "Cartesia rate limit reached — wait a moment"
        case .emptyResponse: "Cartesia returned empty audio data"
        case .voiceFetchFailed: "Failed to fetch Cartesia voices"
        case .networkError(let msg): "Cartesia: \(msg)"
        }
    }
}
