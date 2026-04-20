import AppKit
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settingsStore: SettingsStore
    let onNewChatRequested: () -> Void
    let onConversationSelected: () -> Void
    let onSettingsTapped: () -> Void
    let onHoverChanged: (Bool) -> Void
    @State private var searchText = ""
    @State private var activeSection: SidebarSection = .allChats
    @State private var renamingConversation: ConversationRecord?
    @State private var renameText = ""
    @State private var conversationPendingDeletion: ConversationRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    SidebarBrandHeader(onNewChat: onNewChatRequested)

                    SidebarSearchField(text: $searchText)

                    VStack(alignment: .leading, spacing: 10) {
                        SidebarSectionLabel(title: "Navigate")
                        ForEach(SidebarSection.allCases) { section in
                            SidebarSectionButton(
                                section: section,
                                isSelected: activeSection == section
                            ) {
                                activeSection = section
                            }
                        }
                    }
                    .padding(14)
                    .background(SidebarCardBackground())

                    VStack(alignment: .leading, spacing: AppTheme.itemSpacing) {
                        if groupedConversations.isEmpty {
                            SidebarEmptyState(section: activeSection)
                        } else {
                            ForEach(groupedConversations, id: \.title) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    SidebarSectionLabel(title: group.title)

                                    ForEach(group.items) { conversation in
                                        SidebarConversationRow(
                                            conversation: conversation,
                                            metadata: viewModel.sidebarMetadata(for: conversation),
                                            isSelected: viewModel.selectedConversation?.id == conversation.id
                                        )
                                        .onTapGesture {
                                            viewModel.selectedConversation = conversation
                                            onConversationSelected()
                                        }
                                        .contextMenu {
                                            Button("Rename...") {
                                                renamingConversation = conversation
                                                renameText = conversation.decryptedTitle
                                            }
                                            Divider()
                                            Button("Delete Chat", role: .destructive) {
                                                conversationPendingDeletion = conversation
                                            }
                                        }
                                    }
                                }
                                .padding(14)
                                .background(SidebarCardBackground())
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 12) {
                Button(action: onSettingsTapped) {
                    SidebarActionLabel(title: "Settings", icon: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(SidebarCardBackground())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.sidebarGrey)
        .onHover { onHoverChanged($0) }
        .toolbar(removing: .sidebarToggle)
        .alert("Rename Chat", isPresented: Binding(
            get: { renamingConversation != nil },
            set: { if !$0 { renamingConversation = nil } }
        )) {
            TextField("Chat name", text: $renameText)
            Button("Rename") {
                if let conv = renamingConversation {
                    viewModel.renameConversation(conv, title: renameText)
                }
                renamingConversation = nil
            }
            Button("Cancel", role: .cancel) {
                renamingConversation = nil
            }
        } message: {
            Text("Enter a new name for this conversation.")
        }
        .confirmationDialog(
            "Delete Chat?",
            isPresented: Binding(
                get: { conversationPendingDeletion != nil },
                set: { if !$0 { conversationPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let conversationPendingDeletion {
                    viewModel.selectedConversation = conversationPendingDeletion
                    viewModel.deleteSelectedConversation()
                }
                conversationPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                conversationPendingDeletion = nil
            }
        } message: {
            Text("This permanently deletes the selected chat and its messages.")
        }
    }

    private var groupedConversations: [ConversationGroup] {
        let sectionFiltered = viewModel.conversations.filter { conversation in
            switch activeSection {
            case .allChats:
                return true
            case .recents:
                guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) else {
                    return true
                }
                return conversation.updatedAt >= cutoff
            }
        }

        let filtered = sectionFiltered.filter { conversation in
            viewModel.matchesSearch(conversation, query: searchText)
        }

        return Dictionary(grouping: filtered) { conversation in
            ConversationGroup.title(for: conversation.updatedAt)
        }
        .map { ConversationGroup(title: $0.key, items: $0.value) }
        .sorted(by: { $0.sortRank < $1.sortRank })
    }
}

struct SidebarAppearancePicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(AppTheme.headingFont(12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach(AppAppearance.allCases) { appearance in
                    Button {
                        selection = appearance
                    } label: {
                        Text(appearance.title)
                            .font(AppTheme.uiFont(12, weight: .medium))
                            .foregroundStyle(selection == appearance ? AppTheme.textPrimary : AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selection == appearance ? AppTheme.surfacePrimary : AppTheme.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct SidebarBrandHeader: View {
    let onNewChat: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 10) {
                ValeurLogoMark(size: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Valeur AI")
                        .font(AppTheme.headingFont(16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Conversations")
                        .font(AppTheme.uiFont(12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            Button(action: onNewChat) {
                Image(systemName: "square.and.pencil")
                    .font(AppTheme.uiFont(14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.accentDark, AppTheme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(SidebarCardBackground())

    }
}

struct ValeurLogoMark: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let brandMark = BrandAssetCatalog.brandMark {
                Image(nsImage: brandMark)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .fill(AppTheme.accentStrong)

                    Text("V")
                        .font(AppTheme.headingFont(size * 0.58, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private enum BrandAssetCatalog {
    private final class BundleMarker {}

    static var brandMark: NSImage? {
        let resourceName = NSImage.Name("BrandMark")
        let bundles = [Bundle.main, Bundle(for: BundleMarker.self)]

        for bundle in bundles {
            if let image = bundle.image(forResource: resourceName) {
                return image
            }
        }

        return nil
    }
}

struct SidebarSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textSecondary)
            TextField("Search chats", text: $text)
                .font(AppTheme.uiFont(14, weight: .regular))
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SidebarCardBackground())
    }
}

private struct SidebarSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTheme.headingFont(11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(AppTheme.textSecondary)
            .textCase(.uppercase)
    }
}

private struct SidebarCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
            .fill(AppTheme.surfacePrimary)
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case allChats
    case recents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allChats: "All Chats"
        case .recents: "Recents"
        }
    }

    var icon: String {
        switch self {
        case .allChats: "bubble.left.and.bubble.right"
        case .recents: "clock.arrow.circlepath"
        }
    }

    var emptyMessage: String {
        switch self {
        case .allChats: "No chats match the current search."
        case .recents: "No recent chats from the last 7 days."
        }
    }
}

struct SidebarSectionButton: View {
    let section: SidebarSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SidebarActionLabel(title: section.title, icon: section.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.chromeElevated : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SidebarActionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(AppTheme.uiFont(14, weight: .semibold))
                .frame(width: 16)
            Text(title)
                .font(AppTheme.uiFont(14, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(AppTheme.textPrimary)
    }
}

struct SidebarEmptyState: View {
    let section: SidebarSection

    var body: some View {
        Text(section.emptyMessage)
            .font(AppTheme.uiFont(12, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(SidebarCardBackground())
    }
}

struct SidebarConversationRow: View {
    let conversation: ConversationRecord
    let metadata: ConversationListMetadata
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(metadata.title)
                    .font(AppTheme.uiFont(13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 10)
                ProviderBadge(provider: conversation.provider)
            }

            Text(metadata.summary)
                .font(AppTheme.uiFont(11, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AppTheme.chromeElevated : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }

}

struct ProviderBadge: View {
    let provider: LLMProvider

    var body: some View {
        Text(provider.displayName)
            .font(AppTheme.uiFont(10, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(AppTheme.surfacePrimary.opacity(0.9))
            .foregroundStyle(AppTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}


struct ConversationGroup {
    let title: String
    let items: [ConversationRecord]

    var sortRank: Int {
        switch title {
        case "Today": 0
        case "Previous 7 Days": 1
        case "Previous 30 Days": 2
        default: 3
        }
    }

    static func title(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now), date >= weekAgo {
            return "Previous 7 Days"
        }
        if let monthAgo = calendar.date(byAdding: .day, value: -30, to: .now), date >= monthAgo {
            return "Previous 30 Days"
        }
        return "Older"
    }
}
