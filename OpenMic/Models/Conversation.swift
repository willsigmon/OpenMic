import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var providerType: String
    var personaName: String

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        providerType: AIProviderType = .openAI,
        personaName: String = "Sigmon"
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.providerType = providerType.rawValue
        self.personaName = personaName
        self.messages = []
    }

    var provider: AIProviderType {
        AIProviderType(rawValue: providerType) ?? .openAI
    }

    var lastMessage: Message? {
        messages.max { $0.createdAt < $1.createdAt }
    }

    var displayTitle: String {
        if title == "New Conversation", let first = messages.first {
            return String(first.content.prefix(50))
        }
        return title
    }
}
