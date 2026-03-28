import XCTest

final class OpenMicLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesIntoPrimaryExperienceWithoutFailure() throws {
        let app = XCUIApplication()
        app.launch()

        let readyContent = app.otherElements[LaunchAccessibilityID.rootContent]
        let onboardingContent = app.otherElements[LaunchAccessibilityID.rootOnboarding]
        let launchFailure = app.otherElements[LaunchAccessibilityID.rootFailure]

        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if readyContent.exists || onboardingContent.exists {
                break
            }

            if launchFailure.exists {
                XCTFail("App showed launch failure UI instead of ready content.")
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTAssertTrue(
            readyContent.exists || onboardingContent.exists,
            "Expected onboarding or main app content to appear within 15 seconds."
        )
        XCTAssertFalse(
            launchFailure.exists,
            "App showed launch failure UI instead of ready content."
        )
        XCTAssertFalse(
            readyContent.exists && onboardingContent.exists,
            "App should not present onboarding and main content at the same time."
        )
    }
}

private enum LaunchAccessibilityID {
    static let rootContent = "app.root.content"
    static let rootOnboarding = "app.root.onboarding"
    static let rootFailure = "app.root.failure"
}
