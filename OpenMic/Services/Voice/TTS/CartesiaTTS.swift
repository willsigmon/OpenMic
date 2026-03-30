import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "CartesiaTTS")

/// Cartesia Sonic TTS engine — ultra-low latency (40–90ms).
/// Falls back to SystemTTS on failure.
@MainActor
final class CartesiaTTS: CloudTTSBase {
    private let apiKey: String
    private var voiceId: String

    init(apiKey: String, voiceId: String = "a0e99841-438c-4a64-b679-ae501e7d6091") {
        self.apiKey = apiKey
        self.voiceId = voiceId
        super.init(log: log)
    }

    // MARK: - Configuration

    func setVoice(id: String) {
        self.voiceId = id
    }

    // MARK: - Synthesis

    override func synthesize(text: String) async throws -> Data {
        guard let url = URL(string: "https://api.cartesia.ai/tts/bytes") else {
            throw CartesiaTTSError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("2024-06-10", forHTTPHeaderField: "Cartesia-Version")

        let body: [String: Any] = [
            "transcript": text,
            "model_id": "sonic-2",
            "voice": ["id": voiceId],
            "output_format": [
                "container": "mp3",
                "bit_rate": 128000
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CartesiaTTSError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CartesiaTTSError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw CartesiaTTSError.rateLimited
            }
            log.error("Cartesia TTS HTTP \(httpResponse.statusCode, privacy: .public) (\(data.count, privacy: .public) bytes)")
            throw CartesiaTTSError.synthesizeFailed
        }

        guard !data.isEmpty else {
            throw CartesiaTTSError.emptyResponse
        }

        return data
    }
}
