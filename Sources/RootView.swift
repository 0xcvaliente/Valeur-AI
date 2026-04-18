import AppKit
import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?
    @AppStorage("hasAcceptedTerms") private var hasAcceptedTerms = false

    var body: some View {
        Group {
            if !hasAcceptedTerms {
                TermsView(onAccept: { hasAcceptedTerms = true })
            } else if let viewModel {
                ChatWindowView(viewModel: viewModel, settingsStore: appState.settingsStore)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(WindowAppearanceSynchronizer(colorScheme: appState.settingsStore.appAppearance.colorScheme))
        .task {
            if viewModel == nil {
                let repository = ConversationRepository(context: modelContext)
                let model = ChatViewModel(appState: appState, repository: repository)
                model.load()
                if model.selectedConversation == nil {
                    model.newChat()
                }
                viewModel = model
            }
        }
    }
}
