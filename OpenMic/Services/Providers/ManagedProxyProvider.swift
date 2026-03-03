import Foundation

final class ManagedProxyProvider: AIProvider, @unchecked Sendable {
    struct ManagedProxyResponse: Decodable {
        let text: String?
        let error: String?
    }

    let providerType: AIProviderType

    private let endpointURL: URL
    private let model: String
    private let authTokenProvider: @Sendable () async throws -> String

    init(
        providerType: AIProviderType,
        endpointURL: URL,
        model: String,
        authTokenProvider: @escaping @Sendable () async throws -> String
    ) {
        self.providerType = providerType
        self.endpointURL = endpointURL
        self.model = model
        self.authTokenProvider = authTokenProvider
    }

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        let authToken = try await authTokenProvider()
        let request = try buildRequest(messages: messages, authToken: authToken)
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIProviderError.translate(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.networkError("Invalid managed response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverError = parseServerError(from: data)
            throw AIProviderError.networkError(serverError)
        }

        let decoded = try decodeResponse(data)
        let text = decoded.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw AIProviderError.unknown("Managed provider returned an empty response")
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(text)
            continuation.finish()
        }
    }

    func validateKey() async throws -> Bool {
        do {
            let token = try await authTokenProvider()
            return !token.isEmpty
        } catch {
            return false
        }
    }

    private func buildRequest(
        messages: [ChatMessage],
        authToken: String
    ) throws -> URLRequest {
        let payload = ManagedProxyPayload(
            provider: providerType.rawValue,
            model: model,
            messages: messages.map {
                ManagedProxyMessage(role: $0.role.rawValue, content: $0.content)
            }
        )

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func decodeResponse(_ data: Data) throws -> ManagedProxyResponse {
        do {
            return try JSONDecoder().decode(ManagedProxyResponse.self, from: data)
        } catch {
            throw AIProviderError.unknown("Managed provider returned unreadable data")
        }
    }

    private func parseServerError(from data: Data) -> String {
        guard !data.isEmpty else {
            return "Managed provider request failed"
        }

        if let decoded = try? JSONDecoder().decode(ManagedProxyResponse.self, from: data),
           let message = decoded.error,
           !message.isEmpty {
            return message
        }

        if let message = String(data: data, encoding: .utf8),
           !message.isEmpty {
            return message
        }

        return "Managed provider request failed"
    }
}

private struct ManagedProxyPayload: Encodable {
    let provider: String
    let model: String
    let messages: [ManagedProxyMessage]
}

private struct ManagedProxyMessage: Encodable {
    let role: String
    let content: String
}
