import Foundation

enum UITestLaunchConfiguration {
    enum Screen: String {
        case terms
        case onboarding
        case settings
    }

    private static let arguments = ProcessInfo.processInfo.arguments
    private static let environment = ProcessInfo.processInfo.environment

    static var isEnabled: Bool {
        arguments.contains("--ui-testing") &&
        (environment["XCTestConfigurationFilePath"] != nil ||
         environment["XCTestBundlePath"] != nil)
    }

    static var acceptedTermsOverride: Bool? {
        guard isEnabled else { return nil }
        if let value = environment["UI_TEST_ACCEPTED_TERMS"] {
            return value == "1"
        }
        guard let index = arguments.firstIndex(of: "--ui-testing-accepted-terms"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1] == "1"
    }

    static var opensSettingsOnLaunch: Bool {
        guard isEnabled else { return false }
        return arguments.contains("--ui-testing-open-settings") || environment["UI_TEST_OPEN_SETTINGS"] == "1"
    }

    static var opensWorkspaceOnLaunch: Bool {
        guard isEnabled else { return false }
        return arguments.contains("--ui-testing-open-workspace") || environment["UI_TEST_OPEN_WORKSPACE"] == "1"
    }

    static var dumpsWorkspaceToolbarDebugInfo: Bool {
        guard isEnabled else { return false }
        return arguments.contains("--ui-testing-dump-workspace-toolbar") || environment["UI_TEST_DUMP_WORKSPACE_TOOLBAR"] == "1"
    }

    static var settingsCategory: SettingsCategory? {
        guard isEnabled else { return nil }
        if let value = environment["UI_TEST_SETTINGS_CATEGORY"] {
            return SettingsCategory.allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
        }
        guard let index = arguments.firstIndex(of: "--ui-testing-settings-category"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return SettingsCategory.allCases.first { $0.rawValue.caseInsensitiveCompare(arguments[index + 1]) == .orderedSame }
    }

    static var screen: Screen? {
        guard isEnabled else { return nil }
        if let value = environment["UI_TEST_SCREEN"] {
            return Screen(rawValue: value)
        }
        guard let index = arguments.firstIndex(of: "--ui-testing-screen"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return Screen(rawValue: arguments[index + 1])
    }
}
