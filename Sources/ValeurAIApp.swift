import AppKit
import SwiftUI
import SwiftData

@main
struct ValeurAIApp: App {
    private let modelContainer: ModelContainer
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        let launchEnvironment = ProcessInfo.processInfo.environment
        let persistenceWarningMessage: String?
        // Require XCTest runner env vars alongside the flag so a manually-crafted
        // launch cannot trigger UserDefaults destruction or the in-memory store.
        let isUITesting = launchArguments.contains("--ui-testing") &&
            (launchEnvironment["XCTestBundlePath"] != nil ||
             launchEnvironment["XCTestConfigurationFilePath"] != nil)

        if isUITesting {
            let defaults = UserDefaults.standard
            if launchArguments.contains("--ui-testing-reset-defaults") {
                if let bundleIdentifier = Bundle.main.bundleIdentifier {
                    defaults.removePersistentDomain(forName: bundleIdentifier)
                }
                defaults.removeObject(forKey: "hasAcceptedTerms")
            }
            if let index = launchArguments.firstIndex(of: "--ui-testing-accepted-terms"),
               launchArguments.indices.contains(index + 1) {
                defaults.set(launchArguments[index + 1] == "1", forKey: "hasAcceptedTerms")
            }
        }

        func makePersistenceWarningMessage(for error: Error) -> String {
            let description = (error as NSError).localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = description.isEmpty ? "No additional details were provided by the system." : description
            return "Valeur AI could not open its local database, so the app is running in temporary in-memory mode. New chats and edits will not persist until the storage issue is fixed and the app is restarted.\n\nNext steps:\n1. Close the app.\n2. Check available disk space and Keychain access.\n3. Reopen Valeur AI.\n\nSystem detail: \(detail)"
        }

        func buildContainer() throws -> ModelContainer {
            try ModelContainer(
                for: ConversationRecord.self,
                MessageRecord.self,
                WorkspaceRecord.self,
                WorkspaceBlockRecord.self,
                WorkspaceBlockRevisionRecord.self
            )
        }

        func buildInMemoryContainer() -> ModelContainer {
            do {
                return try ModelContainer(
                    for: ConversationRecord.self,
                    MessageRecord.self,
                    WorkspaceRecord.self,
                    WorkspaceBlockRecord.self,
                    WorkspaceBlockRevisionRecord.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            } catch {
                fatalError("In-memory data store initialization failed: \(error)")
            }
        }

        if isUITesting {
            modelContainer = buildInMemoryContainer()
            persistenceWarningMessage = nil
        } else {
            do {
                modelContainer = try buildContainer()
                persistenceWarningMessage = nil
            } catch {
                modelContainer = buildInMemoryContainer()
                persistenceWarningMessage = makePersistenceWarningMessage(for: error)
            }
        }

        let keychain = KeychainService()
        let settings = SettingsStore(keychain: keychain)
        let serviceFactory = LLMServiceFactory(settingsStore: settings)
        let appState = AppState(
            settingsStore: settings,
            serviceFactory: serviceFactory,
            persistenceWarningMessage: persistenceWarningMessage
        )
        _appState = StateObject(wrappedValue: appState)

    }

    var body: some Scene {
        WindowGroup {
            rootContent
        }
        .commands {
            AppCommands()
        }
    }

    private var rootContent: some View {
        RootView()
            .environmentObject(appState)
            .environmentObject(appState.settingsStore)
            .modelContainer(modelContainer)
    }
}

struct WindowAppearanceSynchronizer: NSViewRepresentable {
    let colorScheme: ColorScheme?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.observe(view: view, colorScheme: colorScheme)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.apply(to: nsView.window, colorScheme: colorScheme)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        private var observers: [NSObjectProtocol] = []

        func observe(view: NSView, colorScheme: ColorScheme?) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let window = view?.window else { return }
                self.apply(to: window, colorScheme: colorScheme)
                let names: [NSNotification.Name] = [
                    NSWindow.didEnterFullScreenNotification,
                    NSWindow.didExitFullScreenNotification
                ]
                for name in names {
                    let obs = NotificationCenter.default.addObserver(
                        forName: name, object: window, queue: .main
                    ) { [weak self, weak window] _ in
                        self?.apply(to: window, colorScheme: colorScheme)
                    }
                    self.observers.append(obs)
                }
            }
        }

        func apply(to window: NSWindow?, colorScheme: ColorScheme?) {
            guard let window else { return }
            guard !UITestLaunchConfiguration.isEnabled else { return }
            guard let colorScheme else {
                window.appearance = nil
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarSeparatorStyle = .none
                stripToolbarBackground(in: window)
                return
            }

            let name: NSAppearance.Name = colorScheme == .dark ? .darkAqua : .aqua
            window.appearance = NSAppearance(named: name)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarSeparatorStyle = .none
            stripToolbarBackground(in: window)
        }

        private func stripToolbarBackground(in window: NSWindow) {
            guard let rootView = window.contentView?.superview else { return }
            for view in rootView.subviews {
                if NSStringFromClass(type(of: view)).contains("TitlebarContainer") {
                    hideVisualEffectViews(in: view)
                }
            }
        }

        private func hideVisualEffectViews(in view: NSView) {
            for sub in view.subviews {
                if sub is NSVisualEffectView {
                    sub.isHidden = true
                }
                hideVisualEffectViews(in: sub)
            }
        }

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let isUITesting = UITestLaunchConfiguration.isEnabled
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.title = "Valeur AI"
                guard !isUITesting else { return }
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.toolbarStyle = .unified
                window.isMovableByWindowBackground = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarSeparatorStyle = .none
                window.toolbar?.showsBaselineSeparator = false
                if let rootView = window.contentView?.superview {
                    for view in rootView.subviews where NSStringFromClass(type(of: view)).contains("TitlebarContainer") {
                        for sub in view.subviews { sub.subviews.forEach { if $0 is NSVisualEffectView { $0.isHidden = true } } }
                    }
                }
            }
        }
    }
}
