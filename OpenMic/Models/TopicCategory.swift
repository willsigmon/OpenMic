import SwiftUI

struct TopicCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let subcategories: [TopicSubcategory]

    var promptCount: Int {
        subcategories.reduce(0) { $0 + $1.prompts.count }
    }
}

struct TopicSubcategory: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let prompts: [TopicPrompt]
}

struct TopicPrompt: Identifiable, Sendable {
    let id: String
    let text: String
    let label: String
}
