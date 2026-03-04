import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "GoogleCloudTTS")

/// Google Cloud Text-to-Speech engine with 300+ voices across Standard/WaveNet/Neural2/Studio tiers.
/// Falls back to SystemTTS on failure.
@MainActor
final class GoogleCloudTTS: CloudTTSBase {
    private let apiKey: String
    private var voiceId: String

    init(apiKey: String, voiceId: String = "en-US-Neural2-A") {
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
        guard let url = URL(string: "https://texttospeech.googleapis.com/v1/text:synthesize") else {
            throw GoogleCloudTTSError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        let body: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": voiceId.components(separatedBy: "-").prefix(2).joined(separator: "-"),
                "name": voiceId
            ],
            "audioConfig": [
                "audioEncoding": "MP3"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCloudTTSError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw GoogleCloudTTSError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw GoogleCloudTTSError.rateLimited
            }
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            log.error("Google Cloud TTS HTTP \(httpResponse.statusCode): \(bodyStr, privacy: .public)")
            throw GoogleCloudTTSError.synthesizeFailed
        }

        // Response contains base64-encoded audio in "audioContent" field
        struct SynthesizeResponse: Decodable {
            let audioContent: String
        }

        let decoded = try JSONDecoder().decode(SynthesizeResponse.self, from: data)

        guard let audioData = Data(base64Encoded: decoded.audioContent), !audioData.isEmpty else {
            throw GoogleCloudTTSError.emptyResponse
        }

        return audioData
    }
}
