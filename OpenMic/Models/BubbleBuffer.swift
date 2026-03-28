import Foundation

/// Shared bubble management for voice conversation UIs.
///
/// Tracks active (streaming) user and assistant bubbles, upserts transcript
/// updates, and caps the buffer at `maxBubbles` to bound memory usage.
@Observable
@MainActor
final class BubbleBuffer {
    private let maxBubbles: Int
    private(set) var bubbles: [ConversationBubble] = []
    private var activeUserBubbleID: UUID?
    private var activeAssistantBubbleID: UUID?

    init(maxBubbles: Int = 64) {
        self.maxBubbles = maxBubbles
    }

    // MARK: - Public API

    func upsert(_ transcript: VoiceTranscript, provider: AIProviderType? = nil) {
        let trimmed = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let existingID: UUID?
        switch transcript.role {
        case .user:
            existingID = activeUserBubbleID
        case .assistant:
            existingID = activeAssistantBubbleID
        case .system:
            existingID = nil
        }

        if let existingID,
           let index = bubbles.firstIndex(where: { $0.id == existingID }) {
            bubbles[index] = ConversationBubble(
                id: existingID,
                role: transcript.role,
                text: trimmed,
                isFinal: transcript.isFinal,
                createdAt: bubbles[index].createdAt,
                provider: provider ?? bubbles[index].provider
            )
        } else {
            let bubble = ConversationBubble(
                role: transcript.role,
                text: trimmed,
                isFinal: transcript.isFinal,
                provider: provider
            )
            bubbles.append(bubble)
            switch transcript.role {
            case .user:
                activeUserBubbleID = bubble.id
            case .assistant:
                activeAssistantBubbleID = bubble.id
            case .system:
                break
            }
        }

        if transcript.isFinal {
            switch transcript.role {
            case .user:
                activeUserBubbleID = nil
            case .assistant:
                activeAssistantBubbleID = nil
            case .system:
                break
            }
        }

        if bubbles.count > maxBubbles {
            bubbles.removeFirst(bubbles.count - maxBubbles)
        }
    }

    func append(_ bubble: ConversationBubble) {
        bubbles.append(bubble)
        if bubbles.count > maxBubbles {
            bubbles.removeFirst(bubbles.count - maxBubbles)
        }
    }

    func replaceAll(_ newBubbles: [ConversationBubble]) {
        bubbles = newBubbles
        resetDraftState()
    }

    func removeAll() {
        bubbles = []
        resetDraftState()
    }

    func resetDraftState() {
        activeUserBubbleID = nil
        activeAssistantBubbleID = nil
    }
}
