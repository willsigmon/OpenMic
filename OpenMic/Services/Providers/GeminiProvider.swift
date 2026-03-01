import Foundation

final class GeminiProvider: AIProvider, @unchecked Sendable {
    let providerType: AIProviderType = .gemini
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-2.0-flash") {
        self.apiKey = apiKey
        self.model = model
    }

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent"
        )
        components?.queryItems = [URLQueryItem(name: "alt", value: "sse")]

        guard let url = components?.url else {
            throw AIProviderError.networkError("Invalid Gemini API URL")
        }

        var contents: [[String: Any]] = []
        var systemInstruction: [String: Any]?

        for msg in messages {
            switch msg.role {
            case .system:
                systemInstruction = [
                    "parts": [["text": msg.content]]
                ]
            case .user:
                contents.append([
                    "role": "user",
                    "parts": [["text": msg.content]]
                ])
            case .assistant:
                contents.append([
                    "role": "model",
                    "parts": [["text": msg.content]]
                ])
            }
        }

        var body: [String: Any] = ["contents": contents]
        if let systemInstruction {
            body["systemInstruction"] = systemInstruction
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw AIProviderError.translate(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.networkError("Invalid response from Gemini")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw AIProviderError.invalidAPIKey
            }
            throw AIProviderError.networkError("Gemini API error (HTTP \(httpResponse.statusCode))")
        }

        let (outputStream, continuation) = AsyncThrowingStream.makeStream(of: String.self)

        let task = Task {
            do {
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))
                    guard let data = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(
                              with: data
                          ) as? [String: Any],
                          let candidates = json["candidates"] as? [[String: Any]],
                          let content = candidates.first?["content"] as? [String: Any],
                          let parts = content["parts"] as? [[String: Any]],
                          let text = parts.first?["text"] as? String else {
                        continue
                    }
                    continuation.yield(text)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return outputStream
    }

    func validateKey() async throws -> Bool {
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models"
        )
        components?.queryItems = []

        guard let url = components?.url else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        return httpResponse.statusCode == 200
    }
}
