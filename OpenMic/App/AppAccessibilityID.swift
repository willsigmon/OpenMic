import Foundation

enum AppAccessibilityID {
    static let rootLoading = "app.root.loading"
    static let rootContent = "app.root.content"
    static let rootOnboarding = "app.root.onboarding"
    static let rootFailure = "app.root.failure"
    static let conversationProviderBadge = "conversation.provider.badge"
    static let conversationSuggestions = "conversation.suggestions"
    static let conversationSuggestionsRefresh = "conversation.suggestions.refresh"

    static func suggestionCard(_ id: String) -> String {
        "conversation.suggestion.\(id)"
    }

    static func bubble(_ role: MessageRole, id: UUID) -> String {
        "conversation.bubble.\(role.rawValue).\(id.uuidString)"
    }
}
