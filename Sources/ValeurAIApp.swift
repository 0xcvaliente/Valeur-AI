import AppKit
import SwiftUI
import SwiftData

@main
struct ValeurAIApp: App {
    private let modelContainer: ModelContainer
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
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

        do {
            modelContainer = try buildContainer()
        } catch {
            print("Persistent data store initialization failed: \(error)")
            modelContainer = buildInMemoryContainer()
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
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.title = "Valeur AI"
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
