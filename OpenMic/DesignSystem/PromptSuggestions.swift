import Foundation

/// Contextual conversation starters that replace the idle greeting.
/// Mixes time-of-day prompts with random fun ones to keep it fresh.
enum PromptSuggestions {

    struct Suggestion: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let icon: String
    }

    // MARK: - Contextual Pools (Time of Day)

    private static let morningCommute: [Suggestion] = [
        Suggestion(text: "Give me a morning news briefing", icon: "newspaper"),
        Suggestion(text: "What's the weather today?", icon: "cloud.sun"),
        Suggestion(text: "Motivate me for the day", icon: "bolt.fill"),
        Suggestion(text: "Tell me something interesting to start my day", icon: "lightbulb"),
    ]

    private static let midday: [Suggestion] = [
        Suggestion(text: "What's happening in the world?", icon: "globe"),
        Suggestion(text: "Tell me a fun fact", icon: "sparkles"),
        Suggestion(text: "Quiz me on something random", icon: "questionmark.circle"),
        Suggestion(text: "Recommend a good lunch spot idea", icon: "fork.knife"),
    ]

    private static let afternoon: [Suggestion] = [
        Suggestion(text: "Catch me up on today's news", icon: "newspaper"),
        Suggestion(text: "What should I make for dinner?", icon: "frying.pan"),
        Suggestion(text: "Tell me a crazy story", icon: "book"),
        Suggestion(text: "Help me decompress", icon: "leaf"),
    ]

    private static let evening: [Suggestion] = [
        Suggestion(text: "What's good to watch tonight?", icon: "tv"),
        Suggestion(text: "Tell me a bedtime story", icon: "moon.stars"),
        Suggestion(text: "Play a word game with me", icon: "textformat.abc"),
        Suggestion(text: "Ask me a deep question", icon: "brain.head.profile"),
    ]

    // MARK: - Weekend Pool

    private static let weekend: [Suggestion] = [
        Suggestion(text: "What fun things can I do today?", icon: "figure.walk"),
        Suggestion(text: "Plan me a road trip", icon: "car.side"),
        Suggestion(text: "Recommend a new podcast", icon: "headphones"),
        Suggestion(text: "Teach me something I didn't know", icon: "graduationcap"),
    ]

    // MARK: - Always Available (Random)

    private static let anytime: [Suggestion] = [
        Suggestion(text: "Tell me a joke", icon: "face.smiling"),
        Suggestion(text: "Tell me a crazy story", icon: "theatermasks"),
        Suggestion(text: "What's trending right now?", icon: "chart.line.uptrend.xyaxis"),
        Suggestion(text: "Explain something complex simply", icon: "lightbulb"),
        Suggestion(text: "Give me a random fun fact", icon: "star"),
        Suggestion(text: "Debate me on something", icon: "bubble.left.and.bubble.right"),
        Suggestion(text: "Ask me a trivia question", icon: "questionmark.diamond"),
        Suggestion(text: "Recommend something new to try", icon: "arrow.triangle.branch"),
        Suggestion(text: "What's a life hack I probably don't know?", icon: "wrench.and.screwdriver"),
        Suggestion(text: "Summarize something cool from history", icon: "clock.arrow.circlepath"),
        Suggestion(text: "Help me settle a debate", icon: "scale.3d"),
        Suggestion(text: "Roast me (gently)", icon: "flame"),
    ]

    // MARK: - Selection Logic

    /// Returns contextual + random suggestions, shuffled.
    static func current(count: Int = 8) -> [Suggestion] {
        let total = max(1, count)
        let contextual = uniqueByText(contextualPool().shuffled())
        let random = uniqueByText(anytime.shuffled())

        let desiredContextCount = min(total, total >= 4 ? 3 : 2)
        let contextPicks = Array(contextual.prefix(desiredContextCount))

        var selected = contextPicks
        let randomPicks = random.filter { candidate in
            !selected.contains(where: { $0.text == candidate.text })
        }
        selected += randomPicks.prefix(max(0, total - selected.count))

        if selected.count < total {
            let fallbackPool = uniqueByText(contextual + random)
            let fallback = fallbackPool.filter { candidate in
                !selected.contains(where: { $0.text == candidate.text })
            }
            selected += fallback.prefix(total - selected.count)
        }

        return Array(selected.prefix(total)).shuffled()
    }

    private static func contextualPool() -> [Suggestion] {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let isWeekend = weekday == 1 || weekday == 7

        // Blend in weekend prompts on weekends
        var pool: [Suggestion]
        switch hour {
        case 5..<9:   pool = morningCommute
        case 9..<14:  pool = midday
        case 14..<19: pool = afternoon
        default:      pool = evening
        }

        if isWeekend {
            pool += weekend
        }

        return pool
    }

    private static func uniqueByText(_ suggestions: [Suggestion]) -> [Suggestion] {
        var seen = Set<String>()
        return suggestions.filter { suggestion in
            seen.insert(suggestion.text).inserted
        }
    }
}

extension PromptSuggestions.Suggestion {
    var topic: String {
        switch icon {
        case "newspaper", "globe", "chart.line.uptrend.xyaxis":
            return "News"
        case "cloud.sun":
            return "Weather"
        case "bolt.fill":
            return "Motivation"
        case "lightbulb":
            return "Learn"
        case "sparkles", "star":
            return "Fun"
        case "questionmark.circle", "questionmark.diamond":
            return "Trivia"
        case "fork.knife", "frying.pan":
            return "Food"
        case "book", "moon.stars", "theatermasks":
            return "Stories"
        case "leaf":
            return "Calm"
        case "tv":
            return "Entertainment"
        case "textformat.abc":
            return "Games"
        case "brain.head.profile":
            return "Deep Talk"
        case "figure.walk":
            return "Outings"
        case "car.side":
            return "Travel"
        case "headphones":
            return "Podcasts"
        case "graduationcap":
            return "Learning"
        case "face.smiling":
            return "Jokes"
        case "bubble.left.and.bubble.right", "scale.3d":
            return "Debate"
        case "arrow.triangle.branch":
            return "Ideas"
        case "wrench.and.screwdriver":
            return "Life Hacks"
        case "clock.arrow.circlepath":
            return "History"
        case "flame":
            return "Roast"
        default:
            return "Chat"
        }
    }
}
