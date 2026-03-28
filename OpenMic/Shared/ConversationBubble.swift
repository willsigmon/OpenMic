import Foundation

struct ConversationBubble: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: MessageRole
    let text: String
    let isFinal: Bool
    let createdAt: Date
    let provider: AIProviderType?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        isFinal: Bool,
        createdAt: Date = Date(),
        provider: AIProviderType? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.isFinal = isFinal
        self.createdAt = createdAt
        self.provider = provider
    }
}
