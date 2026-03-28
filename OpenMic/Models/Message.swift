import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var role: String
    var content: String
    var createdAt: Date
    var durationSeconds: Double?
    var providerType: String?

    var conversation: Conversation?

    init(
        id: UUID = UUID(),
        role: MessageRole = .user,
        content: String,
        durationSeconds: Double? = nil,
        providerType: AIProviderType? = nil
    ) {
        self.id = id
        self.role = role.rawValue
        self.content = content
        self.createdAt = Date()
        self.durationSeconds = durationSeconds
        self.providerType = providerType?.rawValue
    }

    var provider: AIProviderType? {
        guard let providerType else { return nil }
        return AIProviderType(rawValue: providerType)
    }

    var messageRole: MessageRole {
        MessageRole(rawValue: role) ?? .user
    }
}

enum MessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}
