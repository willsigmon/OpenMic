import Foundation
import SwiftAnthropic

final class AnthropicProvider: AIProvider, @unchecked Sendable {
    let providerType: AIProviderType = .anthropic
    private let service: AnthropicService
    private let model: String

    init(apiKey: String, model: String = "claude-sonnet-4-5-20250929") {
        self.service = AnthropicServiceFactory.service(
            apiKey: apiKey,
            betaHeaders: nil
        )
        self.model = model
    }

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        var systemPrompt: String?
        var anthropicMessages: [MessageParameter.Message] = []

        for msg in messages {
            switch msg.role {
            case .system:
                systemPrompt = msg.content
            case .user:
                anthropicMessages.append(
                    .init(role: .user, content: .text(msg.content))
                )
            case .assistant:
                anthropicMessages.append(
                    .init(role: .assistant, content: .text(msg.content))
                )
            }
        }

        let parameters = MessageParameter(
            model: .other(model),
            messages: anthropicMessages,
            maxTokens: 4096,
            system: systemPrompt.map { .text($0) }
        )

        let stream: AsyncThrowingStream<MessageStreamResponse, Error>
        do {
            nonisolated(unsafe) let s = try await service.streamMessage(parameters)
            stream = s
        } catch {
            throw AIProviderError.translate(error)
        }

        let (outputStream, continuation) = AsyncThrowingStream.makeStream(of: String.self)

        let task = Task {
            do {
                for try await result in stream {
                    if Task.isCancelled { break }
                    if let text = result.delta?.text {
                        continuation.yield(text)
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
        let parameters = MessageParameter(
            model: .other(model),
            messages: [.init(role: .user, content: .text("test"))],
            maxTokens: 1
        )

        do {
            _ = try await service.createMessage(parameters)
            return true
        } catch {
            return false
        }
    }
}
