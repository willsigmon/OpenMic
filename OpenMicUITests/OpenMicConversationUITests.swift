import XCTest

/// End-to-end conversation test using a seeded Anthropic key.
/// Run via: xcodebuild test -project ... -scheme OpenMic -only-testing OpenMicUITests/OpenMicConversationUITests
final class OpenMicConversationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Seed Anthropic key so the app bypasses onboarding and uses Claude
        if let key = ProcessInfo.processInfo.environment["OPENMIC_TEST_ANTHROPIC_KEY"],
           !key.isEmpty {
            app.launchEnvironment["OPENMIC_SEED_ANTHROPIC"] = key
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testTappingSuggestionCardSendsToClaude() throws {
        let suggestionContainer = app.otherElements[
            ConversationAccessibilityID.suggestionContainer
        ]
        XCTAssertTrue(
            suggestionContainer.waitForExistence(timeout: 10),
            "Suggestion chips should appear within 10 seconds"
        )

        let suggestionCard = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                ConversationAccessibilityID.suggestionCardPrefix
            )
        ).firstMatch

        let appeared = suggestionCard.waitForExistence(timeout: 10)
        XCTAssertTrue(appeared, "Suggestion cards should appear within 10 seconds")

        let label = suggestionCard.label
        suggestionCard.tap()

        let userBubble = app.otherElements.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label == %@",
                ConversationAccessibilityID.userBubblePrefix,
                label
            )
        ).firstMatch
        XCTAssertTrue(
            userBubble.waitForExistence(timeout: 5),
            "User bubble with '\(label)' should appear after tapping suggestion"
        )

        let assistantBubble = app.otherElements.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                ConversationAccessibilityID.assistantBubblePrefix
            )
        ).firstMatch
        XCTAssertTrue(
            assistantBubble.waitForExistence(timeout: 30),
            "Claude should respond with an assistant bubble within 30 seconds"
        )

        // Take a screenshot of the full conversation
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "claude_response"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testProviderBadgeShowsClaude() throws {
        let claudeBadge = app.buttons[
            ConversationAccessibilityID.providerBadge
        ]
        XCTAssertTrue(
            claudeBadge.waitForExistence(timeout: 10),
            "Provider badge should show Claude"
        )
        XCTAssertTrue(
            claudeBadge.label.localizedCaseInsensitiveContains("Claude")
                || claudeBadge.label.localizedCaseInsensitiveContains("Anthropic"),
            "Provider badge should show Claude or Anthropic"
        )
    }
}

private enum ConversationAccessibilityID {
    static let providerBadge = "conversation.provider.badge"
    static let suggestionContainer = "conversation.suggestions"
    static let suggestionCardPrefix = "conversation.suggestion."
    static let userBubblePrefix = "conversation.bubble.user."
    static let assistantBubblePrefix = "conversation.bubble.assistant."
}
