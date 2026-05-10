import XCTest

final class Valeur_AIUITests: XCTestCase {
    private var interruptionMonitor: NSObjectProtocol?

    override func setUpWithError() throws {
        continueAfterFailure = false
        interruptionMonitor = addUIInterruptionMonitor(withDescription: "Dismiss external dialogs") { alert in
            let buttonLabels = ["Done", "Close", "close", "Cancel"]
            for label in buttonLabels {
                let button = alert.buttons[label].firstMatch
                if button.exists {
                    button.click()
                    return true
                }
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        if let interruptionMonitor {
            removeUIInterruptionMonitor(interruptionMonitor)
            self.interruptionMonitor = nil
        }
    }

    @MainActor
    func testFirstLaunchTermsAcceptanceFlow() throws {
        let app = launchApp(screen: "terms")

        dismissExternalDialogs()
        XCTAssertTrue(app.checkBoxes["terms.agreeCheckbox"].waitForExistence(timeout: 5))
        app.checkBoxes["terms.agreeCheckbox"].click()
        app.buttons["terms.acceptButton"].click()
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
        dismissExternalDialogs()
        app.buttons["settings.deleteAllConversations"].click()

        dismissExternalDialogs()
        let deleteAllButton = app.buttons["settings.confirmDeleteAll"].firstMatch
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 5))
        deleteAllButton.click()

        XCTAssertTrue(app.staticTexts["All conversations deleted."].waitForExistence(timeout: 2))
    }

    private func launchApp(screen: String, settingsCategory: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--ui-testing-reset-defaults"]
        app.launchArguments += ["--ui-testing-screen", screen]
        app.launchEnvironment["XCTestBundlePath"] = Bundle(for: Self.self).bundlePath
        app.launchEnvironment["XCTestConfigurationFilePath"] = "ui-testing"
        app.launchEnvironment["UI_TEST_SCREEN"] = screen
        if let settingsCategory {
            app.launchArguments += ["--ui-testing-settings-category", settingsCategory]
            app.launchEnvironment["UI_TEST_SETTINGS_CATEGORY"] = settingsCategory
        }
        app.launch()
        app.activate()
        return app
    }

    private func openSettings(in app: XCUIApplication) {
        dismissExternalDialogs()
        XCTAssertTrue(app.buttons["settings.category.defaults"].waitForExistence(timeout: 10))
    }

    private func dismissExternalDialogs() {
        let screenshotApp = XCUIApplication(bundleIdentifier: "com.apple.screencaptureui")
        let buttonLabels = ["Done", "Close", "close", "Cancel"]

        for label in buttonLabels {
            let button = screenshotApp.buttons[label].firstMatch
            if button.waitForExistence(timeout: 0.2) {
                button.click()
                break
            }
        }
    }
}
