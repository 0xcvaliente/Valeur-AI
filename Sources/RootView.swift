import AppKit
import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?
    @State private var workspaceViewModel: WorkspaceViewModel?
    @AppStorage("hasAcceptedTerms") private var hasAcceptedTerms = false

    var body: some View {
        Group {
            if !hasAcceptedTerms {
                TermsView(onAccept: { hasAcceptedTerms = true })
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
        .task {
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
