import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppleFoundationModelsProvider: AIProvider, @unchecked Sendable {
    let providerType: AIProviderType = .apple

    func streamChat(
        messages: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw AIProviderError.configurationMissing("Apple Intelligence requires iOS 26 or later")
        }

        let (outputStream, continuation) = AsyncThrowingStream.makeStream(of: String.self)

        let task = Task {
            do {
                let text = try await generateResponse(from: messages)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    continuation.yield(trimmed)
                }
                continuation.finish()
            } catch let providerError as AIProviderError {
                continuation.finish(throwing: providerError)
            } catch {
                continuation.finish(throwing: AIProviderError.translate(error))
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return outputStream
        #else
        throw AIProviderError.configurationMissing("FoundationModels is not available in this build")
        #endif
    }

    func validateKey() async throws -> Bool {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            return false
        }

        let model = SystemLanguageModel.default
        if case .available = model.availability {
            return true
        }
        return false
        #else
        return false
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateResponse(from messages: [ChatMessage]) async throws -> String {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw AIProviderError.configurationMissing(
                "Apple Intelligence unavailable: \(Self.unavailableReason(reason))"
            )
        }

        let session = LanguageModelSession(model: model)
        let response = try await session.respond(to: Self.prompt(from: messages))
        return response.content
    }

    @available(iOS 26.0, *)
    private static func unavailableReason(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            return "device not eligible"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence not enabled"
        case .modelNotReady:
            return "model not ready"
        @unknown default:
            return "unknown reason"
        }
    }
    #endif

    private static func prompt(from messages: [ChatMessage]) -> String {
        var lines: [String] = []
        for message in messages {
            let roleLabel: String
            switch message.role {
            case .system:
                roleLabel = "System"
            case .user:
                roleLabel = "User"
            case .assistant:
                roleLabel = "Assistant"
            }
            lines.append("\(roleLabel): \(message.content)")
        }
        lines.append("Assistant:")
        return lines.joined(separator: "\n")
    }
}
