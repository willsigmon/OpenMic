import Foundation

enum ConversationExporter {

    /// Formats a conversation as shareable plain text.
    static func plainText(from conversation: Conversation) -> String {
        var lines: [String] = []

        lines.append(conversation.displayTitle)
        lines.append(String(repeating: "─", count: 40))

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        lines.append("Provider: \(conversation.provider.displayName)")
        lines.append("Persona: \(conversation.personaName)")
        lines.append("Date: \(formatter.string(from: conversation.createdAt))")
        lines.append("")

        let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        for message in sorted {
            let role = message.messageRole
            let label: String
            switch role {
            case .user: label = "You"
            case .assistant: label = "OpenMic"
            case .system: label = "System"
            }

            let time = formatter.string(from: message.createdAt)
            lines.append("[\(label)] \(time)")
            lines.append(message.content)
            lines.append("")
        }

        lines.append(String(repeating: "─", count: 40))
        lines.append("Exported from OpenMic")

        return lines.joined(separator: "\n")
    }
}
