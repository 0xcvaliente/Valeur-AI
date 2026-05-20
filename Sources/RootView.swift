import AppKit
import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?
    @State private var workspaceViewModel: WorkspaceViewModel?
    @AppStorage("hasAcceptedTerms") private var storedHasAcceptedTerms = false
    @AppStorage("hasCompletedOnboarding") private var storedHasCompletedOnboarding = false
    @State private var uiTestingAcceptedTermsOverride = UITestLaunchConfiguration.acceptedTermsOverride

    var body: some View {
        let hasAcceptedTerms = uiTestingAcceptedTermsOverride ?? storedHasAcceptedTerms
        ZStack {
            AppTheme.backgroundPrimary
                .ignoresSafeArea()

            content(
                hasAcceptedTerms: hasAcceptedTerms,
                hasCompletedOnboarding: storedHasCompletedOnboarding
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(appState.settingsStore.appAppearance.colorScheme)
        .background(WindowAppearanceSynchronizer(colorScheme: appState.settingsStore.appAppearance.colorScheme))
        .background(WindowToolbarStyleSynchronizer(style: .expanded))
        .background(WindowToolbarChromeClearer())
        .alert(
            "Storage Notice",
            isPresented: Binding(
                get: { appState.persistenceWarningMessage != nil },
                set: { if !$0 { appState.persistenceWarningMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                appState.persistenceWarningMessage = nil
            }
        } message: {
            Text(appState.persistenceWarningMessage ?? "")
        }
        .task {
            guard UITestLaunchConfiguration.screen == nil else { return }
            if viewModel == nil || workspaceViewModel == nil {
                let repository = ConversationRepository(context: modelContext)
                let model = ChatViewModel(appState: appState, repository: repository)
                model.load()
                if model.selectedConversation == nil {
                    model.newChat()
                }
                viewModel = model

                let workspaceRepository = WorkspaceRepository(context: modelContext)
                let workspaceModel = WorkspaceViewModel(appState: appState, repository: workspaceRepository)
                workspaceModel.load()
                workspaceViewModel = workspaceModel
            }
        }
    }

    @ViewBuilder
    private func content(hasAcceptedTerms: Bool, hasCompletedOnboarding: Bool) -> some View {
        if UITestLaunchConfiguration.screen == .terms {
            termsView
        } else if UITestLaunchConfiguration.screen == .onboarding {
            onboardingView
        } else if UITestLaunchConfiguration.screen == .settings {
            UITestSettingsHost(appState: appState, modelContext: modelContext)
        } else if !hasAcceptedTerms {
            termsView
        } else if !hasCompletedOnboarding {
            onboardingView
        } else if let viewModel, let workspaceViewModel {
            ChatWindowView(
                viewModel: viewModel,
                workspaceViewModel: workspaceViewModel,
                settingsStore: appState.settingsStore
            )
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var termsView: some View {
        TermsView(onAccept: {
            storedHasAcceptedTerms = true
            storedHasCompletedOnboarding = false
            if uiTestingAcceptedTermsOverride != nil {
                uiTestingAcceptedTermsOverride = true
            }
        })
    }

    private var onboardingView: some View {
        OnboardingView(onComplete: {
            storedHasCompletedOnboarding = true
        })
    }
}

@MainActor
private struct UITestSettingsHost: View {
    @StateObject private var viewModel: ChatViewModel

    init(appState: AppState, modelContext: ModelContext) {
        let repository = ConversationRepository(context: modelContext)
        let model = ChatViewModel(appState: appState, repository: repository)
        model.load()
        if model.selectedConversation == nil {
            model.newChat()
        }
        _viewModel = StateObject(wrappedValue: model)
    }

    var body: some View {
        SettingsView(viewModel: viewModel)
    }
}
