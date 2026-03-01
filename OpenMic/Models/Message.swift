import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var role: String
    var content: String
    var createdAt: Date
    var durationSeconds: Double?

    var conversation: Conversation?

    init(
        id: UUID = UUID(),
        role: MessageRole = .user,
        content: String,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.role = role.rawValue
        self.content = content
        self.createdAt = Date()
        self.durationSeconds = durationSeconds
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
