import XCTest

final class Valeur_AIUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchTermsAcceptanceFlow() throws {
        let app = launchApp(screen: "terms")

        XCTAssertTrue(app.otherElements["terms.root"].waitForExistence(timeout: 3))
        app.checkBoxes["I have read and agree to the Terms & Conditions"].click()
        app.buttons["Accept & Continue"].click()
    }

    @MainActor
    func testSettingsFlowShowsDataPanel() throws {
        let app = launchApp(screen: "settings")

        openSettings(in: app)
        XCTAssertTrue(app.buttons["API Keys"].waitForExistence(timeout: 2))

        app.buttons["Data"].click()
        XCTAssertTrue(app.buttons["Delete All Conversations"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDeleteAllConversationsFlowShowsConfirmationAndSuccessMessage() throws {
        let app = launchApp(screen: "settings")

        openSettings(in: app)
        app.buttons["Data"].click()
        app.buttons["Delete All Conversations"].click()
        app.buttons["Delete All"].click()

        XCTAssertTrue(app.staticTexts["All conversations deleted."].waitForExistence(timeout: 2))
    }

    private func launchApp(screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--ui-testing-reset-defaults"]
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launchEnvironment["UI_TEST_SCREEN"] = screen
        app.launch()
        app.activate()
        return app
    }

    private func openSettings(in app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["settings.root"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Defaults"].waitForExistence(timeout: 2))
    }
}
