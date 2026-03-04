import Foundation
import SwiftData
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "ConversationStore")

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
    ) throws -> Conversation {
        let conversation = Conversation(
            providerType: providerType,
            personaName: personaName
        )
        modelContext.insert(conversation)
        try save()
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
    ) throws -> Message {
        let message = Message(
            role: role,
            content: content,
            durationSeconds: durationSeconds
        )
        message.conversation = conversation
        conversation.messages.append(message)
        conversation.updatedAt = Date()
        try save()
        return message
    }

    func delete(_ conversation: Conversation) throws {
        modelContext.delete(conversation)
        try save()
    }

    func deleteAllConversations() {
        do {
            let all = try fetchAll()
            for conversation in all {
                modelContext.delete(conversation)
            }
            try modelContext.save()
        } catch {
            // Best effort cleanup for account deletion/sign-out flows
        }
    }

    func updateTitle(_ conversation: Conversation, title: String) throws {
        conversation.title = title
        conversation.updatedAt = Date()
        try save()
    }

    private func save() throws {
        try modelContext.save()
    }
}
