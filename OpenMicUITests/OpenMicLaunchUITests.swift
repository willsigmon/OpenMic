import XCTest

final class OpenMicLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToReadyContent() throws {
        let app = XCUIApplication()
        app.launch()

        let readyContent = app.otherElements[LaunchAccessibilityID.rootContent]
        let launchFailure = app.otherElements[LaunchAccessibilityID.rootFailure]

        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if readyContent.exists {
                break
            }

            if launchFailure.exists {
                XCTFail("App showed launch failure UI instead of ready content.")
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTAssertTrue(
            readyContent.exists,
            "Expected ready app content to appear within 15 seconds."
        )
        XCTAssertFalse(
            launchFailure.exists,
            "App showed launch failure UI instead of ready content."
        )
    }
}

private enum LaunchAccessibilityID {
    static let rootContent = "app.root.content"
    static let rootFailure = "app.root.failure"
}
