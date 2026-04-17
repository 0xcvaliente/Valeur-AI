import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ChatWindowView(viewModel: viewModel, settingsStore: appState.settingsStore)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
