import SwiftUI
import UniformTypeIdentifiers

enum SettingsCategory: String, CaseIterable, Identifiable {
    case defaults = "Defaults"
    case appearance = "Appearance"
    case personalization = "Personalization"
    case apiKeys = "API Keys"
    case data = "Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .defaults: "slider.horizontal.3"
        case .appearance: "paintbrush"
        case .personalization: "person.crop.circle"
        case .apiKeys: "key"
        case .data: "externaldrive"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: SettingsCategory? = .defaults

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(SettingsCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            SettingsCategoryRow(
                                title: category.rawValue,
                                systemImage: category.icon,
                                isSelected: selectedCategory == category
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.category.\(category.rawValue.lowercased())")
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))
                        .accessibilityIdentifier("settings.doneButton")
                }
            }
        } detail: {
            Group {
                switch selectedCategory {
                case .defaults:
                    SettingsDefaultsPanel()
                case .appearance:
                    SettingsAppearancePanel()
                case .personalization:
                    SettingsPersonalizationPanel()
                case .apiKeys:
                    SettingsAPIKeysPanel(viewModel: viewModel)
                case .data:
                    SettingsDataPanel()
                case nil:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(settingsStore.appAppearance.colorScheme)
        .tint(AppTheme.accent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.root")
    }
}

private struct SettingsCategoryRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(AppTheme.uiFont(14, weight: .medium))
                .frame(width: 22)

            Text(title)
                .font(AppTheme.uiFont(14, weight: .medium))

            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? Color.white : AppTheme.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.accent)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.clear)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Defaults

private struct SettingsDefaultsPanel: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        SettingsPanelScroll {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                SettingsFieldLabel("Default Provider")
                Picker("Default Provider", selection: Binding(
                    get: { settingsStore.defaultProvider },
                    set: { settingsStore.defaultProvider = $0 }
                )) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(AppTheme.uiFont(14, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .leading)

                SettingsFieldLabel("Model")
                Menu {
                    Section("\(settingsStore.defaultProvider.displayName) Models") {
                        ForEach(settingsStore.defaultProvider.presets) { preset in
                            Button {
                                settingsStore.selectedModel = preset.modelIdentifier
                            } label: {
                                ModelSelectorMenuRow(
                                    preset: preset,
                                    isSelected: settingsStore.selectedModel(for: settingsStore.defaultProvider) == preset.modelIdentifier
                                )
                            }
                        }
                    }
                } label: {
                    SettingsModelPickerButton(
                        provider: settingsStore.defaultProvider,
                        modelIdentifier: settingsStore.selectedModel(for: settingsStore.defaultProvider)
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize(horizontal: false, vertical: true)

                SettingsFieldLabel("Context Window")
                SettingsContextWindowCard(
                    tokenLimit: settingsStore.contextWindowTokens(
                        for: settingsStore.defaultProvider,
                        modelIdentifier: settingsStore.selectedModel(for: settingsStore.defaultProvider)
                    )
                )

                Toggle(isOn: Binding(
                    get: { settingsStore.webSearchEnabled },
                    set: { settingsStore.webSearchEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allow Provider Web Search")
                            .font(AppTheme.uiFont(13, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Off by default. When enabled, OpenAI and Gemini may call their provider-side search tools for the current request.")
                            .font(AppTheme.uiFont(11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(AppTheme.accent)

                Text("This limit is determined by the selected model. The composer meter shows live usage against it, and older messages are trimmed first when the limit is reached.")
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                SettingsFieldLabel("System Prompt")
                TextField("System Prompt", text: Binding(
                    get: { settingsStore.systemPrompt },
                    set: { settingsStore.systemPrompt = $0 }
                ), axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .settingsInputStyle()

                Text("Choose a provider here, then set the model used for that provider. The sidebar selector switches provider for the current chat, and that chat uses the model configured here.")
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Appearance

private struct SettingsAppearancePanel: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        SettingsPanelScroll {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                SettingsFieldLabel("Theme")
                SidebarAppearancePicker(selection: Binding(
                    get: { settingsStore.appAppearance },
                    set: { settingsStore.appAppearance = $0 }
                ))

                SettingsFieldLabel("Font Family")
                Picker("Font Family", selection: Binding(
                    get: { settingsStore.appFontFamilyName },
                    set: { settingsStore.appFontFamilyName = $0 }
                )) {
                    ForEach(AppTheme.fontFamilyOptions(), id: \.self) { family in
                        Text(family == AppTheme.systemFontFamilyName ? "System (macOS)" : family)
                            .tag(family)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(AppTheme.uiFont(14, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .leading)

                SettingsFieldLabel("Font Size")
                Picker("Font Size", selection: Binding(
                    get: { settingsStore.appFontSize },
                    set: { settingsStore.appFontSize = $0 }
                )) {
                    ForEach(AppFontSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(AppTheme.uiFont(14, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Applies across chats, the sidebar, the composer, and settings.")
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Personalization

private struct SettingsPersonalizationPanel: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var isImportingMemoryDocument = false
    @State private var isProcessingMemoryDocument = false
    @State private var saveMessage: String?

    var body: some View {
        SettingsPanelScroll {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                SettingsFieldLabel("User Name")
                TextField("Your name", text: Binding(
                    get: { settingsStore.userName },
                    set: { settingsStore.userName = $0 }
                ))
                .settingsInputStyle()

                SettingsFieldLabel("Custom Instructions")
                TextField(
                    "Describe how Valeur AI should respond, what to prioritize, and any standing preferences.",
                    text: Binding(
                        get: { settingsStore.customInstructions },
                        set: { settingsStore.customInstructions = $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(5, reservesSpace: true)
                .settingsInputStyle()

                SettingsFieldLabel("Memory Document")
                HStack(spacing: 10) {
                    Button("Upload Document") {
                        isImportingMemoryDocument = true
                    }
                    .buttonStyle(AppChromeButtonStyle(tone: .accent))
                    .disabled(isProcessingMemoryDocument)

                    if settingsStore.hasMemoryDocument {
                        Button("Remove Document", role: .destructive) {
                            settingsStore.clearMemoryDocument()
                            saveMessage = "Memory document removed."
                        }
                        .buttonStyle(AppChromeButtonStyle(tone: .secondary))
                        .disabled(isProcessingMemoryDocument)
                    }

                    if isProcessingMemoryDocument {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Importing...")
                                .font(AppTheme.uiFont(11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                if let summary = settingsStore.memoryDocumentSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary)
                            .font(AppTheme.uiFont(11, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("This document is injected as persistent reference memory when it is relevant to the conversation.")
                            .font(AppTheme.uiFont(11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                } else {
                    Text("No memory document uploaded.")
                        .font(AppTheme.uiFont(11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let msg = saveMessage {
                    Text(msg)
                        .font(AppTheme.uiFont(11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingMemoryDocument,
            allowedContentTypes: supportedMemoryDocumentTypes,
            allowsMultipleSelection: false
        ) { result in
            Task {
                isProcessingMemoryDocument = true
                saveMessage = nil
                defer { isProcessingMemoryDocument = false }
                do {
                    guard let url = try result.get().first else { return }
                    try await settingsStore.setMemoryDocument(from: url)
                    saveMessage = "Memory document imported successfully."
                } catch {
                    saveMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - API Keys

private struct SettingsAPIKeysPanel: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var apiKeys: [LLMProvider: String] = [:]
    @State private var saveMessage: String?

    var body: some View {
        SettingsPanelScroll {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsFieldLabel("API Usage")
                    HStack(alignment: .center, spacing: 14) {
                        TokenUsageRingView(
                            usageFraction: viewModel.tokenUsageFraction,
                            inputTokenCount: viewModel.inputTokenCount,
                            outputTokenCount: viewModel.outputTokenCount,
                            totalTokenCount: viewModel.estimatedTokenCount
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Active chat usage")
                                .font(AppTheme.uiFont(13, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("This shows input, output, and total tokens used by the active chat.")
                                .font(AppTheme.uiFont(11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Context Window")
                                .font(AppTheme.uiFont(11, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Configured limit for new and active chats.")
                                .font(AppTheme.uiFont(10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(TokenFormatting.windowLabel(viewModel.contextTokenLimit))
                                .font(AppTheme.monoFont(12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Token budget")
                                .font(AppTheme.monoFont(9, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Saved across chats")
                            .font(AppTheme.uiFont(11, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            Text("Keeps adding as you make new chats.")
                                .font(AppTheme.uiFont(10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(TokenFormatting.windowLabel(viewModel.savedTotalTokenCountAcrossChats))
                                .font(AppTheme.monoFont(12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Input \(TokenFormatting.windowLabel(viewModel.savedInputTokenCountAcrossChats))")
                                .font(AppTheme.monoFont(9, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Output \(TokenFormatting.windowLabel(viewModel.savedOutputTokenCountAcrossChats))")
                                .font(AppTheme.monoFont(9, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                }

                ForEach(LLMProvider.allCases) { provider in
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsFieldLabel(provider.apiKeyLabel)
                        SecureField(provider.apiKeyLabel, text: Binding(
                            get: { apiKeys[provider] ?? "" },
                            set: { newValue in
                                apiKeys[provider] = newValue
                                do {
                                    try settingsStore.setAPIKey(newValue, for: provider)
                                    viewModel.invalidateServiceCache(for: provider)
                                    saveMessage = "API keys are stored securely in your macOS Keychain."
                                } catch {
                                    saveMessage = error.localizedDescription
                                }
                            }
                        ))
                        .settingsInputStyle()
                    }
                }

                if let msg = saveMessage {
                    Text(msg)
                        .font(AppTheme.uiFont(11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .onAppear {
            for provider in LLMProvider.allCases {
                apiKeys[provider] = settingsStore.apiKey(for: provider)
            }
        }
    }
}

// MARK: - Data

private struct SettingsDataPanel: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showDeleteAllAlert = false
    @State private var saveMessage: String?

    var body: some View {
        SettingsPanelScroll {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                Text("Permanently delete every conversation and all of their messages. This action cannot be undone.")
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Button(role: .destructive) {
                    showDeleteAllAlert = true
                } label: {
                    Label("Delete All Conversations", systemImage: "trash")
                }
                .buttonStyle(AppChromeButtonStyle(tone: .destructive))
                .accessibilityIdentifier("settings.deleteAllConversations")
                .alert(
                    "Delete All Conversations?",
                    isPresented: $showDeleteAllAlert
                ) {
                    Button("Delete All", role: .destructive) {
                        NotificationCenter.default.post(name: .deleteAllConversationsRequested, object: nil)
                        saveMessage = "All conversations deleted."
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete every conversation and all messages. You cannot undo this action.")
                }

                if let msg = saveMessage {
                    Text(msg)
                        .font(AppTheme.uiFont(11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Shared layout

private struct SettingsPanelScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
                    .padding(AppTheme.panelPadding)
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.backgroundSecondary.ignoresSafeArea())
    }
}

private struct SettingsFieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppTheme.uiFont(11, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
    }
}

private struct SettingsContextWindowCard: View {
    let tokenLimit: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(TokenFormatting.windowLabel(tokenLimit))
                    .font(AppTheme.monoFont(14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Derived from the selected model")
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "lock.fill")
                .font(AppTheme.uiFont(12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

private struct SettingsInputStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.uiFont(14, weight: .regular))
            .textFieldStyle(.plain)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(AppTheme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
            .foregroundStyle(AppTheme.textPrimary)
    }
}

private struct SettingsModelPickerButton: View {
    let provider: LLMProvider
    let modelIdentifier: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.normalizedModelIdentifier(modelIdentifier))
                    .font(AppTheme.uiFont(14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Version \(provider.versionLabel(for: modelIdentifier))")
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Context \(TokenFormatting.windowLabel(provider.contextWindowTokens(for: modelIdentifier)))")
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(AppTheme.uiFont(11, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

private extension View {
    func settingsInputStyle() -> some View {
        modifier(SettingsInputStyleModifier())
    }
}

private let supportedMemoryDocumentTypes: [UTType] = [
    .plainText,
    .utf8PlainText,
    .text,
    .pdf,
    .json,
    UTType(filenameExtension: "md") ?? .plainText
]
