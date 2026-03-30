import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "DeepgramTTS")

/// Deepgram Aura TTS engine — fast, simple REST API.
/// Falls back to SystemTTS on failure.
@MainActor
final class DeepgramTTS: CloudTTSBase {
    private let apiKey: String
    private var voiceId: String

    init(apiKey: String, voiceId: String = "aura-2-theia-en") {
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
        guard var components = URLComponents(string: "https://api.deepgram.com/v1/speak") else {
            throw DeepgramTTSError.synthesizeFailed
        }
        components.queryItems = [URLQueryItem(name: "model", value: voiceId)]
        guard let url = components.url else {
            throw DeepgramTTSError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepgramTTSError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw DeepgramTTSError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw DeepgramTTSError.rateLimited
            }
            log.error("Deepgram TTS HTTP \(httpResponse.statusCode, privacy: .public) (\(data.count, privacy: .public) bytes)")
            throw DeepgramTTSError.synthesizeFailed
        }

        guard !data.isEmpty else {
            throw DeepgramTTSError.emptyResponse
        }

        return data
    }
}
