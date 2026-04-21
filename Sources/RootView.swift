import AppKit
import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?
    @State private var workspaceViewModel: WorkspaceViewModel?
    @AppStorage("hasAcceptedTerms") private var storedHasAcceptedTerms = false
    @State private var uiTestingAcceptedTermsOverride = UITestLaunchConfiguration.acceptedTermsOverride

    var body: some View {
        let hasAcceptedTerms = uiTestingAcceptedTermsOverride ?? storedHasAcceptedTerms
        Group {
            if UITestLaunchConfiguration.screen == .terms {
                TermsView(onAccept: {
                    storedHasAcceptedTerms = true
                    if uiTestingAcceptedTermsOverride != nil {
                        uiTestingAcceptedTermsOverride = true
                    }
                })
            } else if UITestLaunchConfiguration.screen == .settings {
                UITestSettingsHost(appState: appState, modelContext: modelContext)
            } else if !hasAcceptedTerms {
                TermsView(onAccept: {
                    storedHasAcceptedTerms = true
                    if uiTestingAcceptedTermsOverride != nil {
                        uiTestingAcceptedTermsOverride = true
                    }
                })
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
        .background(WindowAppearanceSynchronizer(colorScheme: appState.settingsStore.appAppearance.colorScheme))
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
