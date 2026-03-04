import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "OpenAITTS")

/// OpenAI TTS engine using the /v1/audio/speech endpoint.
/// Reuses the existing OpenAI API key from keychain.
/// Falls back to SystemTTS on failure.
@MainActor
final class OpenAITTS: CloudTTSBase {
    private let apiKey: String
    private var voice: OpenAITTSVoice
    private var model: OpenAITTSModel

    init(
        apiKey: String,
        voice: OpenAITTSVoice = .nova,
        model: OpenAITTSModel = .tts1
    ) {
        self.apiKey = apiKey
        self.voice = voice
        self.model = model
        super.init(log: log)
    }

    // MARK: - Configuration

    func setVoice(_ voiceName: String) {
        if let v = OpenAITTSVoice(rawValue: voiceName) {
            self.voice = v
        }
    }

    func setModel(_ model: OpenAITTSModel) {
        self.model = model
    }

    // MARK: - Synthesis

    override func synthesize(text: String) async throws -> Data {
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            throw OpenAITTSError.synthesizeFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model.rawValue,
            "input": text,
            "voice": voice.rawValue
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITTSError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw OpenAITTSError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw OpenAITTSError.rateLimited
            }
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            log.error("OpenAI TTS HTTP \(httpResponse.statusCode): \(bodyStr, privacy: .public)")
            throw OpenAITTSError.synthesizeFailed
        }

        guard !data.isEmpty else {
            throw OpenAITTSError.emptyResponse
        }

        return data
    }
}
