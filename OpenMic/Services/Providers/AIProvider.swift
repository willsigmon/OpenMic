import Foundation

struct ChatMessage: Sendable {
    let role: MessageRole
    let content: String
}

protocol AIProvider: Sendable {
    var providerType: AIProviderType { get }

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error>

    func validateKey() async throws -> Bool
}

enum AIProviderError: LocalizedError {
    case invalidAPIKey
    case configurationMissing(String)
    case networkError(String)
    case rateLimited
    case modelUnavailable(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "Invalid API key — check your key in Settings"
        case .configurationMissing(let msg): "\(msg) — configure in Settings"
        case .networkError(let msg): "Network error: \(msg)"
        case .rateLimited: "Rate limited — please wait a moment"
        case .modelUnavailable(let model): "Model unavailable: \(model)"
        case .unknown(let msg): "Error: \(msg)"
        }
    }

    /// Inspects an upstream error and translates it to a user-friendly AIProviderError.
    static func translate(_ error: Error) -> AIProviderError {
        let desc = error.localizedDescription.lowercased()
        let nsError = error as NSError

        // URL connection failures (server not running, no internet)
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return .networkError("No internet connection")
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                return .networkError("Can't reach the server — check your connection")
            case NSURLErrorTimedOut:
                return .networkError("Request timed out — try again")
            default:
                return .networkError(error.localizedDescription)
            }
        }

        // Auth errors from provider SDKs (inspect string descriptions)
        if desc.contains("401") || desc.contains("unauthorized")
            || desc.contains("invalid api key") || desc.contains("invalid x-api-key")
            || desc.contains("authentication") {
            return .invalidAPIKey
        }

        if desc.contains("403") || desc.contains("forbidden") || desc.contains("permission") {
            return .invalidAPIKey
        }

        if desc.contains("429") || desc.contains("rate limit") || desc.contains("too many requests") {
            return .rateLimited
        }

        if desc.contains("404") || desc.contains("not found") || desc.contains("does not exist") {
            return .modelUnavailable(desc)
        }

        return .unknown(error.localizedDescription)
    }
}
