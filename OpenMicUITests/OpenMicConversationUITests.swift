import XCTest

/// End-to-end conversation test using a seeded Anthropic key.
/// Run via: xcodebuild test -project ... -scheme OpenMic-iOSOnly -only-testing OpenMicUITests/OpenMicConversationUITests
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
        // Wait for talk tab to be ready (suggestions visible)
        let suggestionCard = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH[c] 'Give me' OR label BEGINSWITH[c] 'Tell me' OR label BEGINSWITH[c] 'Help me' OR label BEGINSWITH[c] 'Ask me' OR label BEGINSWITH[c] 'What' OR label BEGINSWITH[c] 'Roast' OR label BEGINSWITH[c] 'Recommend'"
        )).firstMatch

        // Give suggestions time to appear (animated in)
        let appeared = suggestionCard.waitForExistence(timeout: 10)
        XCTAssertTrue(appeared, "Suggestion cards should appear within 10 seconds")

        // Tap the first matching suggestion
        let label = suggestionCard.label
        suggestionCard.tap()

        // Wait for user bubble to appear with the prompt text
        let userBubble = app.staticTexts.matching(NSPredicate(
            format: "label == %@", label
        )).firstMatch
        XCTAssertTrue(
            userBubble.waitForExistence(timeout: 5),
            "User bubble with '\(label)' should appear after tapping suggestion"
        )

        // Wait for assistant response — poll until a second static text appears
        var responseAppeared = false
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if app.staticTexts.count >= 2 {
                responseAppeared = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertTrue(responseAppeared, "Claude should respond within 30 seconds")

        // Take a screenshot of the full conversation
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "claude_response"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testProviderBadgeShowsClaude() throws {
        // Provider badge should show "Claude" when Anthropic is active
        let claudeBadge = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Claude' OR label CONTAINS[c] 'Anthropic'")
        ).firstMatch
        XCTAssertTrue(
            claudeBadge.waitForExistence(timeout: 10),
            "Provider badge should show Claude"
        )
    }
}
