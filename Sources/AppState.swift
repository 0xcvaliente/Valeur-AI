import Foundation
import Combine
import SwiftData
import PDFKit
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var selectedConversationID: UUID?
    @Published var draftMessage = ""
    @Published var isStreaming = false
    @Published var lastError: String?

    let settingsStore: SettingsStore
    let serviceFactory: LLMServiceFactory

    init(settingsStore: SettingsStore, serviceFactory: LLMServiceFactory) {
        self.settingsStore = settingsStore
        self.serviceFactory = serviceFactory
    }

    func select(_ conversation: ConversationRecord?) {
        selectedConversationID = conversation?.id
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var conversations: [ConversationRecord] = []
    @Published var selectedConversation: ConversationRecord?
    @Published var composerText = ""
    @Published var draftAttachments: [URL] = []
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var currentModelStatus: String?
    @Published var generationStartTime: Date?
    @Published var lastGenerationDuration: TimeInterval?

    private let appState: AppState
    private let repository: ConversationRepository
    private var activeStreamTask: Task<Void, Never>?

    init(appState: AppState, repository: ConversationRepository) {
        self.appState = appState
        self.repository = repository
    }

    func load() {
        do {
            conversations = try repository.fetchConversations()
            if selectedConversation == nil {
                selectedConversation = conversations.first
            } else if let id = selectedConversation?.id {
                selectedConversation = conversations.first(where: { $0.id == id })
            }
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func newChat() {
        do {
            let provider = appState.settingsStore.defaultProvider
            let conversation = try repository.createConversation(
                provider: provider,
                modelIdentifier: appState.settingsStore.selectedModel(for: provider)
            )
            load()
            selectedConversation = conversation
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func deleteSelectedConversation() {
        cancelStreaming()
        guard let conversation = selectedConversation else { return }
        do {
            try repository.deleteConversation(conversation)
            selectedConversation = nil
            load()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func deleteAllConversations() {
        cancelStreaming()
        do {
            try repository.deleteAllConversations()
            selectedConversation = nil
            load()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func sendCurrentMessage() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = draftAttachments
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }

        activeStreamTask?.cancel()
        activeStreamTask = Task { [weak self] in
            await self?.sendMessage(trimmed, attachments: attachments)
        }
    }

    func retryLastResponse() {
        guard let conversation = selectedConversation else { return }

        activeStreamTask?.cancel()
        activeStreamTask = Task { [weak self] in
            await self?.retryResponse(in: conversation)
        }
    }

    func cancelStreaming() {
        activeStreamTask?.cancel()
        activeStreamTask = nil
        isSending = false
    }

    func invalidateServiceCache(for provider: LLMProvider) {
        appState.serviceFactory.invalidate(for: provider)
    }

    func updateProvider(_ provider: LLMProvider) {
        guard let conversation = selectedConversation else { return }
        do {
            try repository.updateConversation(
                conversation,
                provider: provider,
                modelIdentifier: appState.settingsStore.selectedModel(for: provider)
            )
            load()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func updateModel(_ model: String) {
        guard let conversation = selectedConversation else { return }
        do {
            try repository.updateConversation(conversation, modelIdentifier: model)
            load()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func selectModelPreset(_ preset: LLMModelPreset) {
        guard let conversation = selectedConversation else { return }
        do {
            try repository.updateConversation(
                conversation,
                provider: preset.provider,
                modelIdentifier: preset.modelIdentifier
            )
            load()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func renameConversation(_ conversation: ConversationRecord, title: String) {
        do {
            try repository.renameConversation(conversation, title: title)
            load()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func updateSystemPrompt(_ prompt: String) {
        guard let conversation = selectedConversation else { return }
        do {
            try repository.updateConversation(conversation, systemPromptOverride: prompt)
            load()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func editMessage(_ message: MessageRecord) {
        guard message.role == .user else { return }
        composerText = message.decryptedContent
    }

    var canRetry: Bool {
        guard let selectedConversation else { return false }
        return selectedConversation.messages.contains(where: { $0.role == .assistant })
    }

    var contextTokenLimit: Int {
        if let conversation = selectedConversation {
            return max(
                appState.settingsStore.contextWindowTokens(
                    for: conversation.provider,
                    modelIdentifier: conversation.modelIdentifier
                ),
                1
            )
        }

        return max(appState.settingsStore.contextTokenLimit, 1)
    }

    var inputTokenCount: Int {
        let draftTokenCount = TokenFormatting.estimatedTokenCount(for: composerText)
        return (selectedConversation?.persistedInputTokenCount ?? 0) + draftTokenCount
    }

    var outputTokenCount: Int {
        selectedConversation?.persistedOutputTokenCount ?? 0
    }

    var estimatedTokenCount: Int {
        inputTokenCount + outputTokenCount
    }

    var tokenUsageFraction: Double {
        min(Double(estimatedTokenCount) / Double(contextTokenLimit), 1.0)
    }

    var savedInputTokenCountAcrossChats: Int {
        conversations.reduce(into: 0) { total, conversation in
            total += conversation.persistedInputTokenCount
        }
    }

    var savedOutputTokenCountAcrossChats: Int {
        conversations.reduce(into: 0) { total, conversation in
            total += conversation.persistedOutputTokenCount
        }
    }

    var savedTotalTokenCountAcrossChats: Int {
        savedInputTokenCountAcrossChats + savedOutputTokenCountAcrossChats
    }

    private func sendMessage(_ content: String, attachments: [URL]) async {
        let conversation: ConversationRecord
        if let selectedConversation {
            conversation = selectedConversation
        } else {
            do {
                let provider = appState.settingsStore.defaultProvider
                conversation = try repository.createConversation(
                    provider: provider,
                    modelIdentifier: appState.settingsStore.selectedModel(for: provider)
                )
                selectedConversation = conversation
            } catch {
                errorMessage = displayMessage(for: error)
                return
            }
        }

        isSending = true
        errorMessage = nil
        currentModelStatus = nil
        generationStartTime = Date()
        lastGenerationDuration = nil

        do {
            var msgAttachments: [MessageAttachment] = []
            var attachmentError: Error?
            for url in attachments {
                defer { url.stopAccessingSecurityScopedResource() }
                guard attachmentError == nil else { continue }
                if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize,
                   fileSize > 20 * 1024 * 1024 {
                    attachmentError = ServiceError.providerMessage("Attachment exceeds the 20 MB limit.")
                    continue
                }
                let mime = attachmentMimeType(for: url)
                if let data = try? Data(contentsOf: url) {
                    msgAttachments.append(MessageAttachment(data: data, mimeType: mime))
                }
            }
            if let attachmentError { throw attachmentError }
            
            _ = try repository.appendMessage(role: .user, content: content, attachments: msgAttachments, to: conversation)
            composerText = ""
            draftAttachments = []
            try await generateAssistantReply(in: conversation)
            try repository.retitleConversationIfNeeded(conversation)
        } catch is CancellationError {
            errorMessage = "Response stopped."
        } catch {
            errorMessage = displayMessage(for: error)
        }

        finishStreaming()
    }

    private func retryResponse(in conversation: ConversationRecord) async {
        isSending = true
        errorMessage = nil
        currentModelStatus = nil
        generationStartTime = Date()
        lastGenerationDuration = nil

        do {
            let sortedMessages = conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })
            if let last = sortedMessages.last, last.role == .assistant {
                try repository.deleteMessage(last)
            }
            try await generateAssistantReply(in: conversation)
        } catch is CancellationError {
            errorMessage = "Response stopped."
        } catch {
            errorMessage = displayMessage(for: error)
        }

        finishStreaming()
    }

    private func generateAssistantReply(in conversation: ConversationRecord) async throws {
        let systemPrompt = appState.settingsStore.composedSystemPrompt(
            conversationSystemPrompt: conversation.resolvedSystemPrompt
        )
        let outboundMessages = trimmedOutboundMessages(
            for: conversation,
            systemPrompt: systemPrompt
        )

        let assistantMessage = try repository.appendMessage(role: .assistant, content: "", to: conversation)
        load()

        let provider = conversation.provider
        let model = provider.normalizedModelIdentifier(conversation.modelIdentifier)
        if model != conversation.modelIdentifier {
            try repository.updateConversation(conversation, modelIdentifier: model)
            load()
        }
        let request = ChatRequest(
            messages: outboundMessages,
            systemPrompt: systemPrompt,
            model: model,
            allowsWebSearch: appState.settingsStore.webSearchEnabled
        )

        let service = appState.serviceFactory.makeService(provider: provider)
        var responseText = ""

        do {
            for try await event in service.streamResponse(for: request) {
                try Task.checkCancellation()
                switch event {
                case .started:
                    if provider == .gemini {
                        currentModelStatus = "Reasoning and Searching..."
                    }
                case .token(let token):
                    currentModelStatus = nil
                    responseText += token
                    try repository.streamUpdateMessage(assistantMessage, content: responseText)
                case .status(let statusMsg):
                    currentModelStatus = statusMsg
                case .finished:
                    currentModelStatus = nil
                }
            }
            if !responseText.isEmpty {
                try repository.updateMessage(assistantMessage, content: responseText)
            }
        } catch {
            if responseText.isEmpty {
                try? repository.deleteMessage(assistantMessage)
            } else {
                try? repository.updateMessage(assistantMessage, content: responseText)
            }
            throw error
        }
    }

    private func trimmedOutboundMessages(
        for conversation: ConversationRecord,
        systemPrompt: String?
    ) -> [ChatMessagePayload] {
        let sortedMessages = conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })
        let budget = contextTokenLimit
        let promptTokenCount = TokenFormatting.estimatedTokenCount(for: systemPrompt ?? "")
        let messageBudget = max(budget - promptTokenCount, 1)

        var selectedMessages: [ChatMessagePayload] = []
        var usedTokens = 0

        for record in sortedMessages.reversed() {
            let payload = messagePayload(for: record)
            let payloadTokenCount = TokenFormatting.estimatedTokenCount(for: payload.content)
            if selectedMessages.isEmpty {
                selectedMessages.append(payload)
                usedTokens += payloadTokenCount
                if usedTokens >= messageBudget {
                    break
                }
                continue
            }

            if usedTokens + payloadTokenCount > messageBudget {
                break
            }

            selectedMessages.append(payload)
            usedTokens += payloadTokenCount
        }

        return Array(selectedMessages.reversed())
    }

    private func messagePayload(for record: MessageRecord) -> ChatMessagePayload {
        var decodedAttachments: [MessageAttachment]? = nil
        if let data = record.decryptedAttachmentsData {
            decodedAttachments = try? JSONDecoder().decode([MessageAttachment].self, from: data)
        }
        return ChatMessagePayload(
            id: record.id,
            role: record.role,
            content: record.decryptedContent,
            attachments: decodedAttachments,
            createdAt: record.createdAt
        )
    }

    private func finishStreaming() {
        if let start = generationStartTime {
            lastGenerationDuration = Date().timeIntervalSince(start)
        }
        isSending = false
        currentModelStatus = nil
        generationStartTime = nil
        activeStreamTask = nil
        load()
    }

    private func attachmentMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" { return "application/pdf" }
        guard let utType = UTType(filenameExtension: ext),
              let mime = utType.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mime
    }

    private func displayMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == 3840 {
            return "The AI service returned data in an unexpected format. Check the selected provider and model, then try again."
        }

        return error.localizedDescription
    }
}
