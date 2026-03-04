import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "HumeAITTS")

/// Hume AI Octave TTS engine with emotionally expressive voices.
/// Falls back to SystemTTS on failure.
@MainActor
final class HumeAITTS: CloudTTSBase {
    private let apiKey: String
    private var voiceName: String?

    init(
        apiKey: String,
        voiceName: String? = nil
    ) {
        self.apiKey = apiKey
        self.voiceName = voiceName
        super.init(log: log)
    }

    // MARK: - Configuration

    func setVoice(id: String) {
        self.voiceName = id
    }

    // MARK: - Synthesis

    override func synthesize(text: String) async throws -> Data {
        guard let url = URL(string: "https://api.hume.ai/v0/tts/file") else {
            throw HumeAIError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Hume-Api-Key")

        var body: [String: Any] = [
            "text": text,
            "format": ["type": "mp3"]
        ]

        if let voiceName {
            body["voice"] = ["name": voiceName]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HumeAIError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw HumeAIError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw HumeAIError.rateLimited
            }
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            log.error("Hume AI TTS HTTP \(httpResponse.statusCode): \(bodyStr, privacy: .public)")
            throw HumeAIError.synthesizeFailed
        }

        guard !data.isEmpty else {
            throw HumeAIError.emptyResponse
        }

        return data
    }
}
