import Combine
import SwiftUI

struct ChatWindowView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settingsStore: SettingsStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isSidebarPinned = false
    @State private var showSettings = false
    @State private var hideWorkItem: DispatchWorkItem?
    private let integratedSidebarWidth: CGFloat = 280

    var body: some View {
        splitView
            .background(AppTheme.backgroundPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        togglePinnedSidebar()
                    } label: {
                        Image(systemName: isSidebarPinned ? "sidebar.leading" : "sidebar.left")
                            .font(AppTheme.uiFont(15, weight: .semibold))
                    }
                    .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true, showBorder: false, tight: true, showBackground: false))
                    .help(isSidebarPinned ? "Hide Sidebar" : "Show Sidebar")
                }
                if columnVisibility == .detailOnly {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            viewModel.newChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(AppTheme.uiFont(15, weight: .semibold))
                        }
                        .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true, showBorder: false, tight: true, showBackground: false))
                        .help("New Chat")
                    }
                }
            }
            .navigationTitle("")
            .preferredColorScheme(settingsStore.appAppearance.colorScheme)
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settingsStore)
                    .frame(minWidth: 640, minHeight: 440)
            }
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    columnVisibility = .detailOnly
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deleteAllConversationsRequested)) { _ in
                viewModel.deleteAllConversations()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                showSettings = true
            }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                viewModel: viewModel,
                settingsStore: settingsStore,
                onNewChatRequested: {
                    viewModel.newChat()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        columnVisibility = .detailOnly
                    }
                },
                onConversationSelected: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        columnVisibility = .detailOnly
                    }
                },
                onSettingsTapped: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showSettings = true
                    }
                },
                onHoverChanged: handleHover
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 480)
        } detail: {
            ChatDetailView(viewModel: viewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .overlay(alignment: .leading) {
            if !isSidebarPinned {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 28)
                    .frame(maxHeight: .infinity)
                    .onHover { handleHover($0) }
            }
        }
    }

    private var titlebarSubtitle: String {
        if let selectedConversation = viewModel.selectedConversation {
            let trimmedTitle = selectedConversation.decryptedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                return trimmedTitle
            }
        }
        return "New conversation"
    }

    private func togglePinnedSidebar() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        isSidebarPinned.toggle()
        withAnimation(.easeInOut(duration: 0.2)) {
            columnVisibility = isSidebarPinned ? .all : .detailOnly
        }
    }

    private func handleHover(_ isHovering: Bool) {
        guard !isSidebarPinned else { return }
        hideWorkItem?.cancel()
        hideWorkItem = nil
        if isHovering {
            withAnimation(.easeInOut(duration: 0.2)) {
                columnVisibility = .all
            }
        } else {
            let work = DispatchWorkItem {
                withAnimation(.easeInOut(duration: 0.2)) {
                    columnVisibility = .detailOnly
                }
            }
            hideWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }
    }
}

private struct WindowChromeBackdrop: View {
    let showsSidebarRegion: Bool
    let sidebarWidth: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        AppTheme.chromeElevated,
                        AppTheme.windowChromeBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [
                        AppTheme.chromeAccent.opacity(0.7),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if showsSidebarRegion {
                    LinearGradient(
                        colors: [
                            AppTheme.sidebarGrey.opacity(0.98),
                            AppTheme.windowChromeBackground.opacity(0.92)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: min(sidebarWidth, proxy.size.width))
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(AppTheme.border.opacity(0.6))
                            .frame(width: 1)
                    }
                }

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.screen)

                Rectangle()
                    .fill(AppTheme.border.opacity(0.45))
                    .frame(height: 1)
            }
            .frame(width: proxy.size.width, height: height, alignment: .topLeading)
        }
        .frame(height: height)
    }
}

private struct TitlebarIdentityView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(AppTheme.headingFont(12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(AppTheme.uiFont(10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: 240)
    }
}
