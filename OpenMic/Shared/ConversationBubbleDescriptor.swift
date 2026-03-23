import Foundation

struct ConversationBubbleDescriptor: Equatable, Sendable {
    let assistantHeader: String?
    let carPlayTitle: String
    let carPlayDetail: String
    let carPlaySystemImage: String
    let isUser: Bool
}

enum ConversationBubbleDescriptorFactory {
    static func make(from bubble: ConversationBubble) -> ConversationBubbleDescriptor {
        let detail = normalizedDetailText(from: bubble.text)

        if bubble.role == .user {
            return ConversationBubbleDescriptor(
                assistantHeader: nil,
                carPlayTitle: "You",
                carPlayDetail: detail,
                carPlaySystemImage: "person.fill",
                isUser: true
            )
        }

        let assistantHeader = bubble.isFinal ? "OpenMic" : "OpenMic • Live"
        let icon = bubble.isFinal ? "bubble.left.fill" : "waveform"

        return ConversationBubbleDescriptor(
            assistantHeader: assistantHeader,
            carPlayTitle: assistantHeader,
            carPlayDetail: detail,
            carPlaySystemImage: icon,
            isUser: false
        )
    }

    private static func normalizedDetailText(from text: String, limit: Int = 140) -> String {
        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit - 1)) + "…"
    }
}
