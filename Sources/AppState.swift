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
    @Published var selectedConversation: ConversationRecord? {
        didSet { normalizeComposerModeIfNeeded() }
    }
    @Published var composerText = ""
    @Published var draftAttachments: [URL] = []
    @Published var composerMode: ComposerMode = .chat
    @Published var imageGenerationSize: ImageGenerationSize = .square
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
            normalizeComposerModeIfNeeded()
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
        if isSending {
            cancelStreaming()
            return
        }

        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = draftAttachments
        if composerMode == .image && !canUseImageGeneration {
            composerMode = .chat
            errorMessage = "Image generation is not available for the selected provider or model."
            return
        }
        switch composerMode {
        case .chat:
            guard !trimmed.isEmpty || !attachments.isEmpty else { return }
        case .image:
            guard !trimmed.isEmpty else { return }
        }

        activeStreamTask?.cancel()
        activeStreamTask = Task { [weak self] in
            switch self?.composerMode {
            case .image:
                await self?.generateImage(prompt: trimmed, attachments: attachments)
            default:
                await self?.sendMessage(trimmed, attachments: attachments)
            }
        }
    }

    func retryLastResponse() {
        guard let conversation = selectedConversation else { return }

        activeStreamTask?.cancel()
        activeStreamTask = Task { [weak self] in
            await self?.retryLastAssistantOutput(in: conversation)
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

    func exportConversationHTML() async {
        await exportSelectedConversation(using: { try ConversationExportService.exportConversationHTML($0) })
    }

    func exportConversationPDF() async {
        await exportSelectedConversation(using: { try await ConversationExportService.exportConversationPDF($0) })
    }

    func exportLatestTableCSV() async {
        await exportSelectedConversation(using: { try ConversationExportService.exportLatestTableCSV($0) })
    }

    func exportLatestVisualPNG() async {
        await exportSelectedConversation(using: { try await ConversationExportService.exportLatestVisualPNG($0) })
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
        guard let selectedConversation,
              let lastAssistantMessage = lastAssistantMessage(in: selectedConversation) else {
            return false
        }

        if messageHasImageAttachment(lastAssistantMessage) {
            return canUseImageGeneration
        }

        return true
    }

    var retryActionLabel: String {
        messageHasImageAttachment(lastAssistantMessage(in: selectedConversation)) ? "Regenerate Image" : "Retry"
    }

    var canExportConversationDocument: Bool {
        guard let selectedConversation else { return false }
        return !selectedConversation.messages.isEmpty
    }

    var canExportConversationCSV: Bool {
        ConversationExportService.hasTable(in: selectedConversation)
    }

    var canExportConversationPNG: Bool {
        ConversationExportService.hasVisual(in: selectedConversation)
    }

    var activeProvider: LLMProvider {
        selectedConversation?.provider ?? appState.settingsStore.defaultProvider
    }

    var activeModelIdentifier: String {
        let provider = activeProvider
        let modelIdentifier = selectedConversation?.modelIdentifier ?? appState.settingsStore.selectedModel(for: provider)
        return provider.normalizedModelIdentifier(modelIdentifier)
    }

    var activeModelCapabilities: ModelCapabilities {
        activeProvider.capabilities(for: activeModelIdentifier)
    }

    var canUseImageGeneration: Bool {
        activeModelCapabilities.supportsImageGeneration
    }

    var imageGenerationModelIdentifier: String? {
        activeModelCapabilities.imageGenerationModelIdentifier
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
        do {
            conversation = try resolveConversationForSending()
        } catch {
            errorMessage = displayMessage(for: error)
            return
        }

        isSending = true
        errorMessage = nil
        currentModelStatus = nil
        generationStartTime = Date()
        lastGenerationDuration = nil

        do {
            let msgAttachments = try buildMessageAttachments(from: attachments)
            _ = try repository.appendMessage(role: .user, content: content, attachments: msgAttachments, to: conversation)
            releaseDraftAttachments(attachments)
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

    private func generateImage(prompt: String, attachments: [URL]) async {
        let conversation: ConversationRecord
        do {
            conversation = try resolveConversationForSending()
        } catch {
            errorMessage = displayMessage(for: error)
            return
        }

        isSending = true
        errorMessage = nil
        currentModelStatus = "Generating image..."
        generationStartTime = Date()
        lastGenerationDuration = nil

        do {
            if !attachments.isEmpty {
                throw ServiceError.providerMessage("Image generation currently supports text prompts only. Remove attachments and try again.")
            }

            _ = try repository.appendMessage(role: .user, content: prompt, to: conversation)
            composerText = ""
            try await generateAssistantImage(in: conversation, prompt: prompt)
            try repository.retitleConversationIfNeeded(conversation)
        } catch is CancellationError {
            errorMessage = "Image generation stopped."
        } catch {
            errorMessage = displayMessage(for: error)
        }

        finishStreaming()
    }

    private func retryLastAssistantOutput(in conversation: ConversationRecord) async {
        isSending = true
        errorMessage = nil
        currentModelStatus = nil
        generationStartTime = Date()
        lastGenerationDuration = nil

        do {
            guard let lastAssistantMessage = lastAssistantMessage(in: conversation) else {
                finishStreaming()
                return
            }

            if messageHasImageAttachment(lastAssistantMessage) {
                guard let prompt = promptForImageRetry(in: conversation, replacing: lastAssistantMessage) else {
                    throw ServiceError.providerMessage("Could not find the prompt used to generate the last image.")
                }
                try await generateAssistantImage(
                    in: conversation,
                    prompt: prompt,
                    replacing: lastAssistantMessage
                )
            } else {
                try await generateAssistantReply(
                    in: conversation,
                    replacing: lastAssistantMessage,
                    preservePartialOnFailure: false
                )
            }
        } catch is CancellationError {
            errorMessage = messageHasImageAttachment(lastAssistantMessage(in: conversation)) ? "Image generation stopped." : "Response stopped."
        } catch {
            errorMessage = displayMessage(for: error)
        }

        finishStreaming()
    }

    private func generateAssistantImage(
        in conversation: ConversationRecord,
        prompt: String,
        replacing replacedMessage: MessageRecord? = nil
    ) async throws {
        let provider = conversation.provider
        let model = provider.normalizedModelIdentifier(conversation.modelIdentifier)
        if model != conversation.modelIdentifier {
            try repository.updateConversation(conversation, modelIdentifier: model)
            load()
        }

        let capabilities = provider.capabilities(for: model)
        guard let imageModel = capabilities.imageGenerationModelIdentifier else {
            throw ServiceError.providerMessage("Image generation is not available for the selected \(provider.displayName) model.")
        }

        currentModelStatus = "Generating image..."
        let service = appState.serviceFactory.makeService(provider: provider)
        let response = try await service.generateImage(
            for: ImageGenerationRequest(
                prompt: prompt,
                model: imageModel,
                size: imageGenerationSize
            )
        )

        _ = try repository.appendMessage(
            role: .assistant,
            content: imageGenerationCaption(for: response, originalPrompt: prompt),
            attachments: response.images,
            to: conversation
        )

        if let replacedMessage {
            try repository.deleteMessage(replacedMessage)
        }
    }

    private func generateAssistantReply(
        in conversation: ConversationRecord,
        replacing replacedMessage: MessageRecord? = nil,
        preservePartialOnFailure: Bool = true
    ) async throws {
        let systemPrompt = appState.settingsStore.composedSystemPrompt(
            conversationSystemPrompt: conversation.resolvedSystemPrompt
        )
        let outboundMessages = trimmedOutboundMessages(
            for: conversation,
            systemPrompt: systemPrompt,
            excludingMessageID: replacedMessage?.id
        )

        let assistantMessage = try repository.appendMessage(role: .assistant, content: "", to: conversation)
        load()

        let provider = conversation.provider
        let model = provider.normalizedModelIdentifier(conversation.modelIdentifier)
        if model != conversation.modelIdentifier {
            try repository.updateConversation(conversation, modelIdentifier: model)
            load()
        }
        let capabilities = provider.capabilities(for: model)
        let request = ChatRequest(
            messages: outboundMessages,
            systemPrompt: systemPrompt,
            model: model,
            allowsWebSearch: appState.settingsStore.webSearchEnabled && capabilities.supportsWebSearch
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
                if let replacedMessage {
                    try repository.deleteMessage(replacedMessage)
                }
            }
        } catch {
            if responseText.isEmpty || !preservePartialOnFailure {
                try? repository.deleteMessage(assistantMessage)
            } else {
                try? repository.updateMessage(assistantMessage, content: responseText)
            }
            throw error
        }
    }

    private func trimmedOutboundMessages(
        for conversation: ConversationRecord,
        systemPrompt: String?,
        excludingMessageID: UUID? = nil
    ) -> [ChatMessagePayload] {
        let sortedMessages = conversation.messages
            .filter { message in
                guard let excludingMessageID else { return true }
                return message.id != excludingMessageID
            }
            .sorted(by: { $0.createdAt < $1.createdAt })
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

    private func resolveConversationForSending() throws -> ConversationRecord {
        if let selectedConversation {
            return selectedConversation
        }

        let provider = appState.settingsStore.defaultProvider
        let conversation = try repository.createConversation(
            provider: provider,
            modelIdentifier: appState.settingsStore.selectedModel(for: provider)
        )
        selectedConversation = conversation
        load()
        return conversation
    }

    private func exportSelectedConversation(
        using exporter: (ConversationRecord) async throws -> ExportedFile
    ) async {
        guard let selectedConversation else {
            errorMessage = ConversationExportError.noConversation.errorDescription
            return
        }

        do {
            let exportedFile = try await exporter(selectedConversation)
            try save(exportedFile)
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    private func save(_ exportedFile: ExportedFile) throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = exportedFile.suggestedFilename
        panel.allowedContentTypes = [exportedFile.contentType]

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        try exportedFile.data.write(to: destinationURL, options: .atomic)
    }

    private func normalizeComposerModeIfNeeded() {
        if composerMode == .image && !canUseImageGeneration {
            composerMode = .chat
        }
    }

    private func lastAssistantMessage(in conversation: ConversationRecord?) -> MessageRecord? {
        guard let conversation else { return nil }
        return conversation.messages
            .sorted(by: { $0.createdAt < $1.createdAt })
            .last(where: { $0.role == .assistant })
    }

    private func messageHasImageAttachment(_ message: MessageRecord?) -> Bool {
        guard let message,
              let data = message.decryptedAttachmentsData,
              let attachments = try? JSONDecoder().decode([MessageAttachment].self, from: data) else {
            return false
        }
        return attachments.contains(where: { $0.mimeType.hasPrefix("image/") })
    }

    private func promptForImageRetry(in conversation: ConversationRecord, replacing message: MessageRecord) -> String? {
        let sortedMessages = conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })
        guard let messageIndex = sortedMessages.firstIndex(where: { $0.id == message.id }) else {
            return nil
        }

        guard let promptMessage = sortedMessages[..<messageIndex]
            .reversed()
            .first(where: { $0.role == .user }) else {
            return nil
        }

        let prompt = promptMessage.decryptedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt.isEmpty ? nil : prompt
    }

    private func imageGenerationCaption(for response: ImageGenerationResponse, originalPrompt: String) -> String {
        let revisedPrompt = response.revisedPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedOriginalPrompt = originalPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !revisedPrompt.isEmpty, revisedPrompt != trimmedOriginalPrompt {
            return "> Revised prompt\n\n\(revisedPrompt)"
        }
        return ""
    }

    private func buildMessageAttachments(from urls: [URL]) throws -> [MessageAttachment] {
        try urls.map { url in
            let mimeType = try supportedAttachmentMimeType(for: url)

            do {
                let data = try Data(contentsOf: url)
                return MessageAttachment(data: data, mimeType: mimeType)
            } catch {
                throw ServiceError.providerMessage(
                    "Could not read \(url.lastPathComponent). Remove it and attach it again."
                )
            }
        }
    }

    private func supportedAttachmentMimeType(for url: URL) throws -> String {
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        if let fileSize = resourceValues.fileSize, fileSize > 20 * 1024 * 1024 {
            throw ServiceError.providerMessage("Attachment exceeds the 20 MB limit.")
        }

        if let contentType = resourceValues.contentType {
            if contentType.conforms(to: .pdf) {
                return "application/pdf"
            }

            if contentType.conforms(to: .image) {
                return contentType.preferredMIMEType ?? attachmentMimeType(for: url)
            }
        }

        let fallbackMimeType = attachmentMimeType(for: url)
        if fallbackMimeType == "application/pdf" || fallbackMimeType.hasPrefix("image/") {
            return fallbackMimeType
        }

        throw ServiceError.providerMessage("Only image and PDF attachments are supported right now.")
    }

    private func releaseDraftAttachments(_ attachments: [URL]) {
        for url in attachments {
            url.stopAccessingSecurityScopedResource()
        }
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
