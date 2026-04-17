import Combine
import SwiftUI

struct ChatWindowView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settingsStore: SettingsStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                viewModel: viewModel,
                settingsStore: settingsStore,
                onNewChatRequested: {
                    viewModel.newChat()
                    columnVisibility = .detailOnly
                },
                onConversationSelected: {
                    columnVisibility = .detailOnly
                }
            )
                .navigationSplitViewColumnWidth(min: 250, ideal: 286, max: 320)
        } detail: {
            ChatDetailView(
                viewModel: viewModel,
                isSidebarVisible: columnVisibility != .detailOnly,
                onSidebarToggle: toggleSidebar
            )
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(settingsStore.appAppearance.colorScheme)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChatRequested)) { _ in
            viewModel.newChat()
            columnVisibility = .detailOnly
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteAllConversationsRequested)) { _ in
            viewModel.deleteAllConversations()
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }
}
