import Foundation

/// Randomized, personality-driven microcopy throughout the app.
/// Keeps the experience feeling fresh and alive — never robotic.
enum Microcopy {

    // MARK: - Voice State Labels

    enum Status {
        static func label(for state: VoiceSessionState) -> String {
            switch state {
            case .idle: "Ready"
            case .listening: "Listening…"
            case .processing: "Thinking…"
            case .speaking: "Speaking…"
            case .error: "Try again"
            }
        }
    }

    // MARK: - Empty States

    enum EmptyState {
        static let historyTitles = [
            "No conversations yet",
            "Quiet in here...",
            "Your road trip awaits",
            "Nothing here yet",
        ]

        static let historySubtitles = [
            "Tap Talk to start your first conversation.",
            "Head over to Talk and say hello.",
            "Your conversations will show up here.",
            "Start a chat — I'll remember it for you.",
        ]

        static var historyTitle: String {
            historyTitles.randomElement()!
        }

        static var historySubtitle: String {
            historySubtitles.randomElement()!
        }
    }

    // MARK: - Greetings (idle state personality)

    enum Greeting {
        private static let timeOfDayGreetings: [String] = {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12:
                return [
                    "Good morning! Where are we headed?",
                    "Morning! Ready to roll?",
                    "Rise and drive!",
                ]
            case 12..<17:
                return [
                    "Afternoon! Need anything?",
                    "Hey there, what's up?",
                    "Good afternoon! How's the drive?",
                ]
            case 17..<21:
                return [
                    "Evening! Heading home?",
                    "Good evening! What can I help with?",
                    "Hey! How was your day?",
                ]
            default:
                return [
                    "Night owl! Where to?",
                    "Late night drive? I'm here.",
                    "Burning the midnight oil?",
                ]
            }
        }()

        static var greeting: String {
            timeOfDayGreetings.randomElement()!
        }
    }

    // MARK: - Loading Messages

    enum Loading {
        private static let phrases = [
            "Warming up...",
            "Getting ready...",
            "Almost there...",
            "Setting the stage...",
            "Tuning in...",
        ]

        static var message: String {
            phrases.randomElement()!
        }
    }

    // MARK: - Settings Subtitles

    enum Settings {
        static let aiProviders = "Choose your copilot's brain"
        static let voice = "How I sound when I talk back"
        static let personas = "Different personalities for different vibes"
        static let about = "The fine print"
    }
}
