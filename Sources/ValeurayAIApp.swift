import AppKit
import SwiftUI
import SwiftData

@main
struct ValeurayAIApp: App {
    private let modelContainer: ModelContainer
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        func buildContainer() throws -> ModelContainer {
            try ModelContainer(for: ConversationRecord.self, MessageRecord.self)
        }

        do {
            modelContainer = try buildContainer()
        } catch {
            let fm = FileManager.default
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeFile = appSupport
                    .appending(path: Bundle.main.bundleIdentifier ?? "com.sehford.valeurayai.macosapp")
                    .appending(path: "default.store")
                try? fm.removeItem(at: storeFile)
            }
            do {
                modelContainer = try buildContainer()
            } catch let finalError {
                fatalError("Data store initialization failed after recovery attempt: \(finalError)")
            }
        }

        let keychain = KeychainService()
        let settings = SettingsStore(keychain: keychain)
        let serviceFactory = LLMServiceFactory(settingsStore: settings)
        _appState = StateObject(
            wrappedValue: AppState(
                settingsStore: settings,
                serviceFactory: serviceFactory
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.settingsStore)
                .modelContainer(modelContainer)
        }
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(appState.settingsStore)
                .frame(width: 560, height: 440)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
