import Foundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "GoogleCloudTTS")

// MARK: - Google Cloud Voice

struct GoogleCloudVoice: Identifiable, Codable, Sendable {
    let name: String
    let languageCodes: [String]
    let ssmlGender: String
    let naturalSampleRateHertz: Int

    var id: String { name }

    var displayName: String {
        // "en-US-Neural2-A" → "Neural2 A"
        let parts = name.split(separator: "-")
        if parts.count >= 4 {
            return "\(parts[2]) \(parts[3])"
        }
        return name
    }

    var tier: String {
        if name.contains("Studio") { return "Studio" }
        if name.contains("Neural2") { return "Neural2" }
        if name.contains("Wavenet") { return "WaveNet" }
        return "Standard"
    }

    var genderLabel: String {
        switch ssmlGender {
        case "MALE": "Male"
        case "FEMALE": "Female"
        default: "Neutral"
        }
    }
}

// MARK: - Voice Manager

actor GoogleCloudVoiceManager {
    private var cachedVoices: [GoogleCloudVoice] = []
    private var cacheTime: Date?
    private let cacheDuration: TimeInterval = 300

    func voices(apiKey: String) async throws -> [GoogleCloudVoice] {
        if let cached = cacheTime, Date().timeIntervalSince(cached) < cacheDuration, !cachedVoices.isEmpty {
            return cachedVoices
        }

        guard let url = URL(string: "https://texttospeech.googleapis.com/v1/voices") else {
            throw GoogleCloudTTSError.voiceFetchFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCloudTTSError.voiceFetchFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw GoogleCloudTTSError.invalidAPIKey
            }
            throw GoogleCloudTTSError.voiceFetchFailed
        }

        struct VoicesResponse: Decodable {
            let voices: [GoogleCloudVoice]?
        }

        let decoded = try JSONDecoder().decode(VoicesResponse.self, from: data)
        let englishVoices = (decoded.voices ?? [])
            .filter { $0.languageCodes.contains(where: { $0.hasPrefix("en") }) }
            .sorted { $0.name < $1.name }
        cachedVoices = englishVoices
        cacheTime = Date()
        return englishVoices
    }

    func clearCache() {
        cachedVoices = []
        cacheTime = nil
    }
}

// MARK: - Errors

enum GoogleCloudTTSError: LocalizedError {
    case synthesizeFailed
    case invalidAPIKey
    case apiKeyMissing
    case rateLimited
    case emptyResponse
    case voiceFetchFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .synthesizeFailed: "Google Cloud TTS synthesis failed"
        case .invalidAPIKey: "Invalid Google Cloud API key"
        case .apiKeyMissing: "Google Cloud API key not configured"
        case .rateLimited: "Google Cloud rate limit reached — wait a moment"
        case .emptyResponse: "Google Cloud returned empty audio data"
        case .voiceFetchFailed: "Failed to fetch Google Cloud voices"
        case .networkError(let msg): "Google Cloud TTS: \(msg)"
        }
    }
}
