import Testing
@testable import OpenMic

@Suite("Prompt Suggestions")
struct PromptSuggestionsTests {
    @Test("Returns requested unique count")
    func returnsRequestedUniqueCount() {
        for _ in 0..<25 {
            let suggestions = PromptSuggestions.current(count: 8)
            #expect(suggestions.count == 8)
            #expect(Set(suggestions.map(\.text)).count == suggestions.count)
        }
    }

    @Test("Enforces minimum count")
    func enforcesMinimumCount() {
        let suggestions = PromptSuggestions.current(count: 0)
        #expect(suggestions.count == 1)
    }

    @Test("Suggestions have non-empty text and icon")
    func suggestionContentIsPresent() {
        let suggestions = PromptSuggestions.current(count: 8)
        #expect(suggestions.allSatisfy { !$0.text.isEmpty })
        #expect(suggestions.allSatisfy { !$0.icon.isEmpty })
    }
}
