import Foundation
import SwiftData

@MainActor
final class ConversationStore {
    private let modelContainer: ModelContainer

    var modelContext: ModelContext {
        modelContainer.mainContext
    }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func create(
        providerType: AIProviderType = .openAI,
        personaName: String = "Sigmon"
    ) -> Conversation {
        let conversation = Conversation(
            providerType: providerType,
            personaName: personaName
        )
        modelContext.insert(conversation)
        try? modelContext.save()
        return conversation
    }

    func fetchAll() throws -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Conversation? {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func addMessage(
        to conversation: Conversation,
        role: MessageRole,
        content: String,
        durationSeconds: Double? = nil
    ) -> Message {
        let message = Message(
            role: role,
            content: content,
            durationSeconds: durationSeconds
        )
        message.conversation = conversation
        conversation.messages.append(message)
        conversation.updatedAt = Date()
        try? modelContext.save()
        return message
    }

    func delete(_ conversation: Conversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
    }

    func updateTitle(_ conversation: Conversation, title: String) {
        conversation.title = title
        conversation.updatedAt = Date()
        try? modelContext.save()
    }
}
