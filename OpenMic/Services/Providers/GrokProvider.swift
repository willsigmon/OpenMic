import Foundation
import SwiftOpenAI

final class GrokProvider: AIProvider, @unchecked Sendable {
    let providerType: AIProviderType = .grok
    private let service: OpenAIService
    private let model: String

    init(apiKey: String, model: String = "grok-2") {
        // Grok uses OpenAI-compatible API at api.x.ai
        self.service = OpenAIServiceFactory.service(
            apiKey: apiKey,
            overrideBaseURL: "https://api.x.ai"
        )
        self.model = model
    }

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        let openAIMessages = messages.map { msg -> ChatCompletionParameters.Message in
            switch msg.role {
            case .system: .init(role: .system, content: .text(msg.content))
            case .user: .init(role: .user, content: .text(msg.content))
            case .assistant: .init(role: .assistant, content: .text(msg.content))
            }
        }

        let parameters = ChatCompletionParameters(
            messages: openAIMessages,
            model: .custom(model)
        )

        let stream: AsyncThrowingStream<ChatCompletionChunkObject, Error>
        do {
            nonisolated(unsafe) let s = try await service.startStreamedChat(parameters: parameters)
            stream = s
        } catch {
            throw AIProviderError.translate(error)
        }

        let (outputStream, continuation) = AsyncThrowingStream.makeStream(of: String.self)

        let task = Task {
            do {
                for try await result in stream {
                    if Task.isCancelled { break }
                    if let content = result.choices?.first?.delta?.content {
                        continuation.yield(content)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: AIProviderError.translate(error))
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return outputStream
    }

    func validateKey() async throws -> Bool {
        let parameters = ChatCompletionParameters(
            messages: [.init(role: .user, content: .text("test"))],
            model: .custom(model),
            maxTokens: 1
        )

        do {
            _ = try await service.startChat(parameters: parameters)
            return true
        } catch {
            return false
        }
    }
}
