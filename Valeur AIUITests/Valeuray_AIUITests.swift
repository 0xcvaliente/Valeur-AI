import XCTest

final class Valeur_AIUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchTermsAcceptanceFlow() throws {
        let app = launchApp(screen: "terms")

        XCTAssertTrue(app.checkBoxes["I have read and agree to the Terms & Conditions"].waitForExistence(timeout: 5))
        app.checkBoxes["I have read and agree to the Terms & Conditions"].click()
        app.buttons["Accept & Continue"].click()
    }

    @MainActor
    func testSettingsFlowShowsDataPanel() throws {
        let app = launchApp(screen: "settings", settingsCategory: "Data")

        openSettings(in: app)
        XCTAssertTrue(app.buttons["settings.category.appearance"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["settings.deleteAllConversations"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDeleteAllConversationsFlowShowsConfirmationAndSuccessMessage() throws {
        let app = launchApp(screen: "settings", settingsCategory: "Data")

        openSettings(in: app)
        app.buttons["settings.deleteAllConversations"].click()
        app.sheets.buttons["Delete All"].click()

        XCTAssertTrue(app.staticTexts["All conversations deleted."].waitForExistence(timeout: 2))
    }

    private func launchApp(screen: String, settingsCategory: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--ui-testing-reset-defaults"]
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launchEnvironment["UI_TEST_SCREEN"] = screen
        if let settingsCategory {
            app.launchEnvironment["UI_TEST_SETTINGS_CATEGORY"] = settingsCategory
        }
        app.launch()
        app.activate()
        return app
    }

    private func openSettings(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["settings.category.defaults"].waitForExistence(timeout: 5))
    }
}
