import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var apiKeys: [LLMProvider: String] = [:]
    @State private var saveMessage: String?
    @State private var isImportingMemoryDocument = false
    @State private var showDeleteAllAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsCard(title: "Defaults") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsFieldLabel("Default Provider")
                        Picker("Default Provider", selection: providerBinding) {
                            ForEach(LLMProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .font(AppTheme.uiFont(14, weight: .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)

                        SettingsFieldLabel("Model")
                        TextField(
                            "Model",
                            text: modelBinding,
                            prompt: Text(settingsStore.defaultProvider.defaultModel)
                        )
                        .settingsInputStyle()

                        Toggle(isOn: webSearchBinding) {
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

                        SettingsFieldLabel("System Prompt")
                        TextField("System Prompt", text: systemPromptBinding, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .settingsInputStyle()

                        Text("Choose a provider here, then set the model used for that provider. The sidebar selector switches provider for the current chat, and that chat uses the model configured here.")
                            .font(AppTheme.uiFont(11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                SettingsCard(title: "Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        SidebarAppearancePicker(selection: Binding(
                            get: { settingsStore.appAppearance },
                            set: { settingsStore.appAppearance = $0 }
                        ))

                        SettingsFieldLabel("Font Size")
                        Picker("Font Size", selection: fontSizeBinding) {
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

                SettingsCard(title: "Personalization") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsFieldLabel("User Name")
                        TextField("Your name", text: userNameBinding)
                            .settingsInputStyle()

                        SettingsFieldLabel("Custom Instructions")
                        TextField(
                            "Describe how Valeuray AI should respond, what to prioritize, and any standing preferences.",
                            text: customInstructionsBinding,
                            axis: .vertical
                        )
                        .lineLimit(5, reservesSpace: true)
                        .settingsInputStyle()

                        SettingsFieldLabel("Memory Document")
                        HStack(spacing: 10) {
                            Button("Upload Document") {
                                isImportingMemoryDocument = true
                            }
                            .buttonStyle(.borderedProminent)

                            if settingsStore.hasMemoryDocument {
                                Button("Remove Document", role: .destructive) {
                                    settingsStore.clearMemoryDocument()
                                    saveMessage = "Memory document removed."
                                }
                                .buttonStyle(.bordered)
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
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                                    .strokeBorder(AppTheme.border, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                        } else {
                            Text("No memory document uploaded.")
                                .font(AppTheme.uiFont(11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                SettingsCard(title: "API Keys") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(LLMProvider.allCases) { provider in
                            VStack(alignment: .leading, spacing: 8) {
                                SettingsFieldLabel(provider.apiKeyLabel)
                                SecureField(provider.apiKeyLabel, text: apiKeyBinding(for: provider))
                                    .settingsInputStyle()
                            }
                        }
                    }
                }

                SettingsCard(title: "Data") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permanently delete every conversation and all of their messages. This action cannot be undone.")
                            .font(AppTheme.uiFont(11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)

                        Button(role: .destructive) {
                            showDeleteAllAlert = true
                        } label: {
                            Label("Delete All Conversations", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .alert(
                            "Delete All Conversations?",
                            isPresented: $showDeleteAllAlert
                        ) {
                            Button("Delete All", role: .destructive) {
                                deleteAllConversations()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will permanently delete every conversation and all messages. You cannot undo this action.")
                        }
                    }
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(AppTheme.uiFont(11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
        }
        .background(SettingsSurfaceBackground())
        .preferredColorScheme(settingsStore.appAppearance.colorScheme)
        .fileImporter(
            isPresented: $isImportingMemoryDocument,
            allowedContentTypes: supportedMemoryDocumentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleMemoryDocumentImport(result)
        }
        .onAppear {
            for provider in LLMProvider.allCases {
                apiKeys[provider] = settingsStore.apiKey(for: provider)
            }
        }
    }

    private var providerBinding: Binding<LLMProvider> {
        Binding(
            get: { settingsStore.defaultProvider },
            set: { settingsStore.defaultProvider = $0 }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { settingsStore.selectedModel },
            set: { settingsStore.selectedModel = $0 }
        )
    }

    private var systemPromptBinding: Binding<String> {
        Binding(
            get: { settingsStore.systemPrompt },
            set: { settingsStore.systemPrompt = $0 }
        )
    }

    private var webSearchBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.webSearchEnabled },
            set: { settingsStore.webSearchEnabled = $0 }
        )
    }

    private var customInstructionsBinding: Binding<String> {
        Binding(
            get: { settingsStore.customInstructions },
            set: { settingsStore.customInstructions = $0 }
        )
    }

    private var userNameBinding: Binding<String> {
        Binding(
            get: { settingsStore.userName },
            set: { settingsStore.userName = $0 }
        )
    }

    private var fontSizeBinding: Binding<AppFontSize> {
        Binding(
            get: { settingsStore.appFontSize },
            set: { settingsStore.appFontSize = $0 }
        )
    }

    private func apiKeyBinding(for provider: LLMProvider) -> Binding<String> {
        Binding(
            get: { apiKeys[provider] ?? "" },
            set: { newValue in
                apiKeys[provider] = newValue
                do {
                    try settingsStore.setAPIKey(newValue, for: provider)
                    saveMessage = "API keys are stored securely in your macOS Keychain."
                } catch {
                    saveMessage = error.localizedDescription
                }
            }
        )
    }

    private func handleMemoryDocumentImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            try settingsStore.setMemoryDocument(from: url)
            saveMessage = "Memory document imported successfully."
        } catch {
            saveMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteAllConversations() {
        NotificationCenter.default.post(name: .deleteAllConversationsRequested, object: nil)
        saveMessage = "All conversations deleted."
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

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(AppTheme.headingFont(14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            content
        }
        .padding(16)
        .background(AppTheme.surfacePrimary)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
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

private struct SettingsSurfaceBackground: View {
    var body: some View {
        AppTheme.backgroundSecondary
            .ignoresSafeArea()
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
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
            .foregroundStyle(AppTheme.textPrimary)
    }
}

private extension View {
    func settingsInputStyle() -> some View {
        modifier(SettingsInputStyleModifier())
    }
}
