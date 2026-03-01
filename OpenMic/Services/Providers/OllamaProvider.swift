import Foundation

final class OllamaProvider: AIProvider, @unchecked Sendable {
    let providerType: AIProviderType = .ollama
    private let baseURL: String
    private let model: String

    init(
        baseURL: String = "http://localhost:11434",
        model: String = "llama3.2"
    ) {
        self.baseURL = baseURL
        self.model = model
    }

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw AIProviderError.networkError("Invalid Ollama URL: \(baseURL)")
        }

        let ollamaMessages = messages.map { msg -> [String: String] in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        let body: [String: Any] = [
            "model": model,
            "messages": ollamaMessages,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw AIProviderError.translate(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.networkError("Invalid response from Ollama")
        }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw AIProviderError.modelUnavailable("Model '\(model)' not found — run 'ollama pull \(model)' first")
            }
            throw AIProviderError.networkError("Ollama error (HTTP \(httpResponse.statusCode))")
        }

        let (outputStream, continuation) = AsyncThrowingStream.makeStream(of: String.self)

        let task = Task {
            do {
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard !line.isEmpty,
                          let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(
                              with: data
                          ) as? [String: Any] else {
                        continue
                    }

                    // Ollama native format: {"message": {"content": "..."}, "done": false}
                    if let message = json["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        continuation.yield(content)
                    }

                    if json["done"] as? Bool == true {
                        break
                    }
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
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            return false
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
}
