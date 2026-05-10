import Combine
import SwiftUI

struct ChatWindowView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var workspaceViewModel: WorkspaceViewModel
    @ObservedObject var settingsStore: SettingsStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isSidebarPinned = false
    @State private var isSidebarHovered = false
    @State private var isSidebarStripHovered = false
    @State private var showSettings = false
    @State private var showWorkspace = false
    @State private var workspaceColumnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isWorkspaceSidebarPinned = false
    @State private var isWorkspaceSidebarHovered = false
    @State private var isWorkspaceSidebarStripHovered = false
    @State private var hideWorkItem: DispatchWorkItem?
    @State private var workspaceHideWorkItem: DispatchWorkItem?
    @State private var isShowingDeleteWorkspaceAlert = false
    @State private var chatSidebarUpdateSource: SidebarUpdateSource?
    @State private var workspaceSidebarUpdateSource: SidebarUpdateSource?
    private let sidebarHoverStripWidth: CGFloat = 20

    var body: some View {
        ZStack(alignment: .top) {
            contentView
                .padding(.top, showsChatTitlebarControls ? AppTheme.titlebarBackdropHeight : 0)

            if showsChatTitlebarControls {
                chatTitlebarControls
            }
        }
            .background(AppTheme.backgroundPrimary.ignoresSafeArea())
            .background(WindowTitleSynchronizer(title: windowTitle))
            .background(WindowToolbarStyleSynchronizer(style: .expanded))
            .background(WindowToolbarChromeClearer())
            .navigationTitle("")
            .preferredColorScheme(settingsStore.appAppearance.colorScheme)
            .alert("Error", isPresented: chatErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Workspace Error", isPresented: workspaceErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(workspaceViewModel.errorMessage ?? "")
            }
            .alert("Delete Workspace?", isPresented: $isShowingDeleteWorkspaceAlert) {
                Button("Delete", role: .destructive) {
                    workspaceViewModel.deleteSelectedWorkspace()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes the selected workspace and all of its blocks.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .newChatRequested)) { _ in
                showWorkspace = false
                showSettings = false
                viewModel.newChat()
                withAnimation(.easeInOut(duration: 0.2)) {
                    columnVisibility = .detailOnly
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deleteAllConversationsRequested)) { _ in
                viewModel.deleteAllConversations()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                showWorkspace = false
                withAnimation(.easeInOut(duration: 0.18)) {
                    showSettings = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportConversationPDFRequested)) { _ in
                Task { await viewModel.exportConversationPDF() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportConversationDOCXRequested)) { _ in
                Task { await viewModel.exportConversationDOCX() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportConversationHTMLRequested)) { _ in
                Task { await viewModel.exportConversationHTML() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportLatestTableCSVRequested)) { _ in
                Task { await viewModel.exportLatestTableCSV() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportLatestTableXLSXRequested)) { _ in
                Task { await viewModel.exportLatestTableXLSX() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportLatestVisualPNGRequested)) { _ in
                Task { await viewModel.exportLatestVisualPNG() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openWorkspaceRequested)) { _ in
                withAnimation(.easeInOut(duration: 0.18)) {
                    showWorkspace = true
                }
            }
            .onChange(of: columnVisibility) { _, newValue in
                handleExternalSidebarVisibilityChange(
                    newValue,
                    source: &chatSidebarUpdateSource,
                    isPinned: &isSidebarPinned
                )
            }
            .onChange(of: workspaceColumnVisibility) { _, newValue in
                handleExternalSidebarVisibilityChange(
                    newValue,
                    source: &workspaceSidebarUpdateSource,
                    isPinned: &isWorkspaceSidebarPinned
                )
            }
            .onAppear(perform: applyUITestLaunchConfiguration)
    }

    @ViewBuilder
    private var contentView: some View {
        if showWorkspace {
            workspaceContent
        } else {
            splitView
        }
    }

    private var workspaceContent: some View {
        WorkspaceView(
            viewModel: workspaceViewModel,
            columnVisibility: $workspaceColumnVisibility,
            isSidebarPinned: isWorkspaceSidebarPinned,
            sidebarHoverStripWidth: sidebarHoverStripWidth,
            onToggleSidebarPin: togglePinnedWorkspaceSidebar,
            onSidebarHoverChanged: handleWorkspaceSidebarHover,
            onSidebarStripHoverChanged: handleWorkspaceSidebarStripHover,
            onClose: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showWorkspace = false
                }
            }
        )
        .environmentObject(settingsStore)
    }

    private var showsChatTitlebarControls: Bool {
        !showWorkspace && !showSettings
    }

    private var chatTitlebarControls: some View {
        TransparentTitlebarRow {
            Button {
                togglePinnedSidebar()
            } label: {
                ToolbarIconLabel(systemName: isSidebarPinned ? "sidebar.leading" : "sidebar.left")
            }
            .buttonStyle(ToolbarTransparentCircleButtonStyle())

            if columnVisibility == .detailOnly {
                Button {
                    viewModel.newChat()
                } label: {
                    ToolbarIconLabel(systemName: "square.and.pencil")
                }
                .buttonStyle(ToolbarTransparentCircleButtonStyle())
            }

            toneClusterButton
            llmClusterButton

            if viewModel.composerMode == .chat {
                webClusterButton
            }

            workspaceClusterButton
            exportClusterButton
        }
    }

    private var toneClusterButton: some View {
        Menu {
            ForEach(ChatTone.allCases) { tone in
                Button {
                    settingsStore.chatTone = tone
                } label: {
                    HStack {
                        Label(tone.title, systemImage: tone.icon)
                        if settingsStore.chatTone == tone {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ClusterIcon(
                systemName: "waveform",
                isActive: settingsStore.chatTone != .balanced
            )
            .toolbarTransparentCircleChrome()
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var llmClusterButton: some View {
        LLMSelectorMenu(viewModel: viewModel, settingsStore: settingsStore, style: .iconOnly)
    }

    private var webClusterButton: some View {
        Button {
            settingsStore.webSearchEnabled.toggle()
        } label: {
            ClusterIcon(
                systemName: "globe",
                isActive: settingsStore.webSearchEnabled
            )
        }
        .buttonStyle(ToolbarTransparentCircleButtonStyle())
    }

    private var workspaceClusterButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showWorkspace = true
            }
        } label: {
            ClusterIcon(systemName: "square.split.2x1", isActive: false)
        }
        .buttonStyle(ToolbarTransparentCircleButtonStyle())
    }

    private var exportClusterButton: some View {
        Menu {
            Button("Conversation as PDF") {
                Task { await viewModel.exportConversationPDF() }
            }
            .disabled(!viewModel.canExportConversationDocument)

            Button("Conversation as DOCX") {
                Task { await viewModel.exportConversationDOCX() }
            }
            .disabled(!viewModel.canExportConversationDocument)

            Button("Conversation as HTML") {
                Task { await viewModel.exportConversationHTML() }
            }
            .disabled(!viewModel.canExportConversationDocument)

            Divider()

            Button("Latest Table as CSV") {
                Task { await viewModel.exportLatestTableCSV() }
            }
            .disabled(!viewModel.canExportConversationCSV)

            Button("Latest Table as XLSX") {
                Task { await viewModel.exportLatestTableXLSX() }
            }
            .disabled(!viewModel.canExportConversationCSV)

            Button("Latest Visual as PNG") {
                Task { await viewModel.exportLatestVisualPNG() }
            }
            .disabled(!viewModel.canExportConversationPNG)
        } label: {
            ClusterIcon(systemName: "square.and.arrow.up", isActive: false)
                .toolbarTransparentCircleChrome()
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .tint(AppTheme.accent)
    }

    private var splitView: some View {
        HStack(spacing: 0) {
            if showsSidebar(for: columnVisibility) && !showSettings {
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
                        showSettings = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            columnVisibility = .detailOnly
                        }
                    },
                    onSettingsTapped: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showSettings = true
                        }
                    },
                    onHoverChanged: handleSidebarHover
                )
                .frame(minWidth: 290, idealWidth: 310, maxWidth: 380)
                .padding(.leading, 12)
                .padding(.vertical, 12)
            }

            Group {
                if showSettings {
                    SettingsView(
                        viewModel: viewModel,
                        onDone: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showSettings = false
                            }
                        }
                    )
                } else {
                    ChatDetailView(
                        viewModel: viewModel,
                        workspaceViewModel: workspaceViewModel,
                        onOpenWorkspace: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showWorkspace = true
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .leading) {
            if !isSidebarPinned {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: sidebarHoverStripWidth)
                    .frame(maxHeight: .infinity)
                    .onHover { handleSidebarStripHover($0) }
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
        if isSidebarPinned {
            isSidebarHovered = false
            isSidebarStripHovered = false
        }
        chatSidebarUpdateSource = .pinToggle
        setChatSidebarVisibility(isSidebarPinned ? .all : .detailOnly)
    }

    private func togglePinnedWorkspaceSidebar() {
        workspaceHideWorkItem?.cancel()
        workspaceHideWorkItem = nil
        isWorkspaceSidebarPinned.toggle()
        if isWorkspaceSidebarPinned {
            isWorkspaceSidebarHovered = false
            isWorkspaceSidebarStripHovered = false
        }
        workspaceSidebarUpdateSource = .pinToggle
        setWorkspaceSidebarVisibility(isWorkspaceSidebarPinned ? .all : .detailOnly)
    }

    private func handleWorkspaceSidebarHover(_ isHovering: Bool) {
        guard !isWorkspaceSidebarPinned else { return }
        isWorkspaceSidebarHovered = isHovering
        updateWorkspaceSidebarHoverState()
    }

    private func handleWorkspaceSidebarStripHover(_ isHovering: Bool) {
        guard !isWorkspaceSidebarPinned else { return }
        isWorkspaceSidebarStripHovered = isHovering
        updateWorkspaceSidebarHoverState()
    }

    private func updateWorkspaceSidebarHoverState() {
        guard !isWorkspaceSidebarPinned else { return }
        workspaceHideWorkItem?.cancel()
        workspaceHideWorkItem = nil

        if isWorkspaceSidebarHovered || isWorkspaceSidebarStripHovered {
            workspaceSidebarUpdateSource = .hover
            setWorkspaceSidebarVisibility(.all)
            return
        }

        let work = DispatchWorkItem {
            guard !isWorkspaceSidebarPinned, !isWorkspaceSidebarHovered, !isWorkspaceSidebarStripHovered else { return }
            workspaceSidebarUpdateSource = .hover
            setWorkspaceSidebarVisibility(.detailOnly)
        }
        workspaceHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func applyUITestLaunchConfiguration() {
        if UITestLaunchConfiguration.opensWorkspaceOnLaunch, !showWorkspace {
            showWorkspace = true
        }

        guard UITestLaunchConfiguration.opensSettingsOnLaunch, !showSettings else { return }
        showSettings = true
    }

    private func handleSidebarHover(_ isHovering: Bool) {
        guard !isSidebarPinned else { return }
        isSidebarHovered = isHovering
        updateSidebarHoverState()
    }

    private func handleSidebarStripHover(_ isHovering: Bool) {
        guard !isSidebarPinned else { return }
        isSidebarStripHovered = isHovering
        updateSidebarHoverState()
    }

    private func updateSidebarHoverState() {
        guard !isSidebarPinned else { return }
        hideWorkItem?.cancel()
        hideWorkItem = nil

        if isSidebarHovered || isSidebarStripHovered {
            chatSidebarUpdateSource = .hover
            setChatSidebarVisibility(.all)
            return
        }

        let work = DispatchWorkItem {
            guard !isSidebarPinned, !isSidebarHovered, !isSidebarStripHovered else { return }
            chatSidebarUpdateSource = .hover
            setChatSidebarVisibility(.detailOnly)
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func setChatSidebarVisibility(_ visibility: NavigationSplitViewVisibility) {
        guard columnVisibility != visibility else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            columnVisibility = visibility
        }
    }

    private func setWorkspaceSidebarVisibility(_ visibility: NavigationSplitViewVisibility) {
        guard workspaceColumnVisibility != visibility else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            workspaceColumnVisibility = visibility
        }
    }

    private var windowTitle: String {
        if showWorkspace {
            let trimmedTitle = workspaceViewModel.selectedWorkspace?.decryptedTitle
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedTitle.isEmpty ? "Workspace" : trimmedTitle
        }

        if showSettings {
            return "Settings"
        }

        return titlebarSubtitle
    }

    private func handleExternalSidebarVisibilityChange(
        _ newValue: NavigationSplitViewVisibility,
        source: inout SidebarUpdateSource?,
        isPinned: inout Bool
    ) {
        guard source == nil else {
            source = nil
            return
        }

        isPinned = showsSidebar(for: newValue)
    }

    private func showsSidebar(for visibility: NavigationSplitViewVisibility) -> Bool {
        switch visibility {
        case .detailOnly:
            return false
        default:
            return true
        }
    }

    private var chatErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var workspaceErrorBinding: Binding<Bool> {
        Binding(
            get: { workspaceViewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    workspaceViewModel.errorMessage = nil
                }
            }
        )
    }
}

private enum SidebarUpdateSource {
    case hover
    case pinToggle
}

private struct WindowTitleSynchronizer: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.title = title
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
