import AppKit
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settingsStore: SettingsStore
    let onNewChatRequested: () -> Void
    let onConversationSelected: () -> Void
    @State private var searchText = ""
    @State private var activeSection: SidebarSection = .allChats

    var body: some View {
        ZStack {
            SidebarBackground()

            VStack(alignment: .leading, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        SidebarBrandHeader(onNewChat: onNewChatRequested)

                        SidebarAppearancePicker(selection: $settingsStore.appAppearance)

                        LLMSelectorMenu(viewModel: viewModel, settingsStore: settingsStore)

                        SidebarSearchField(text: $searchText)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Navigate")
                                .font(AppTheme.headingFont(12, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)

                            ForEach(SidebarSection.allCases) { section in
                                SidebarSectionButton(
                                    section: section,
                                    isSelected: activeSection == section
                                ) {
                                    activeSection = section
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            if groupedConversations.isEmpty {
                                SidebarEmptyState(section: activeSection)
                            } else {
                                ForEach(groupedConversations, id: \.title) { group in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(group.title)
                                            .font(AppTheme.headingFont(12, weight: .semibold))
                                            .foregroundStyle(AppTheme.textSecondary)

                                        ForEach(group.items) { conversation in
                                            SidebarConversationRow(
                                                conversation: conversation,
                                                isSelected: viewModel.selectedConversation?.id == conversation.id
                                            )
                                            .onTapGesture {
                                                viewModel.selectedConversation = conversation
                                                onConversationSelected()
                                            }
                                            .contextMenu {
                                                Button("Delete Chat", role: .destructive) {
                                                    viewModel.selectedConversation = conversation
                                                    viewModel.deleteSelectedConversation()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 12) {
                    Rectangle()
                        .fill(AppTheme.border.opacity(0.7))
                        .frame(height: 1)

                    SettingsLink {
                        SidebarActionLabel(title: "Settings", icon: "gearshape")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .toolbar(removing: .sidebarToggle)
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
            searchText.isEmpty ||
            conversation.decryptedTitle.localizedCaseInsensitiveContains(searchText) ||
            conversation.messages.contains(where: { $0.decryptedContent.localizedCaseInsensitiveContains(searchText) })
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
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                                    .strokeBorder(selection == appearance ? AppTheme.borderStrong : AppTheme.border, lineWidth: 1)
                            }
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
        HStack {
            HStack(spacing: 10) {
                ValeurayLogoMark(size: 22)

                Text("Valeuray AI")
                    .font(AppTheme.headingFont(20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            Button(action: onNewChat) {
                Image(systemName: "square.and.pencil")
                    .font(AppTheme.uiFont(14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.surfaceSecondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                            .strokeBorder(AppTheme.border, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

struct ValeurayLogoMark: View {
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
            Image(systemName: "sparkles")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceSecondary)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
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
                .background(isSelected ? AppTheme.surfaceSecondary : Color.clear)
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
            .background(AppTheme.surfaceSecondary)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

struct SidebarConversationRow: View {
    let conversation: ConversationRecord
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(conversation.decryptedTitle)
                    .font(AppTheme.uiFont(13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 10)
                ProviderBadge(provider: conversation.provider)
            }

            Text(summaryText)
                .font(AppTheme.uiFont(11, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AppTheme.surfaceSecondary : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }

    private var summaryText: String {
        if let lastMessage = conversation.messages.sorted(by: { $0.createdAt > $1.createdAt }).first {
            return String(
                lastMessage.decryptedContent
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(72)
            )
        }
        return "No messages yet"
    }
}

struct ProviderBadge: View {
    let provider: LLMProvider

    var body: some View {
        Text(provider.displayName)
            .font(AppTheme.uiFont(9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.04))
            .foregroundStyle(AppTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

struct SidebarBackground: View {
    var body: some View {
        AppTheme.sidebarGrey
            .ignoresSafeArea()
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
