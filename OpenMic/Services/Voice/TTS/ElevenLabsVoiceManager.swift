import Foundation

/// Fetches and caches available ElevenLabs voices.
@MainActor
final class ElevenLabsVoiceManager {
    private var cachedVoices: [ElevenLabsVoice] = []
    private var lastFetchDate: Date?
    private let cacheLifetime: TimeInterval = 300 // 5 minutes

    /// Returns cached voices, or fetches from API if stale/empty.
    func voices(apiKey: String) async throws -> [ElevenLabsVoice] {
        if let lastFetchDate, Date().timeIntervalSince(lastFetchDate) < cacheLifetime,
           !cachedVoices.isEmpty {
            return cachedVoices
        }
        let fetched = try await fetchVoices(apiKey: apiKey)
        cachedVoices = fetched
        lastFetchDate = Date()
        return fetched
    }

    func clearCache() {
        cachedVoices = []
        lastFetchDate = nil
    }

    // MARK: - API

    private func fetchVoices(apiKey: String) async throws -> [ElevenLabsVoice] {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices") else {
            throw ElevenLabsError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ElevenLabsError.synthesizeFailed
        }

        if http.statusCode == 401 {
            throw ElevenLabsError.invalidAPIKey
        }
        guard http.statusCode == 200 else {
            throw ElevenLabsError.synthesizeFailed
        }

        let decoded = try JSONDecoder().decode(ElevenLabsVoicesResponse.self, from: data)
        return decoded.voices.sorted { $0.name < $1.name }
    }
}

// MARK: - Response Models

struct ElevenLabsVoicesResponse: Codable, Sendable {
    let voices: [ElevenLabsVoice]
}

struct ElevenLabsVoice: Codable, Sendable, Identifiable {
    let voiceId: String
    let name: String
    let category: String?
    let labels: [String: String]?
    let previewUrl: String?

    var id: String { voiceId }

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
        case name
        case category
        case labels
        case previewUrl = "preview_url"
    }

    var categoryLabel: String {
        category?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Custom"
    }

    var accent: String? {
        labels?["accent"]
    }

    var gender: String? {
        labels?["gender"]
    }

    var age: String? {
        labels?["age"]
    }

    var descriptive: String? {
        labels?["descriptive"]
    }

    /// Short subtitle from labels
    var subtitle: String {
        [gender?.capitalized, age, accent?.capitalized, descriptive]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
