import Foundation
import SwiftData

@MainActor
final class ConversationRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchConversations() throws -> [ConversationRecord] {
        var descriptor = FetchDescriptor<ConversationRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.messages]
        let conversations = try context.fetch(descriptor)
        let didMigrateLegacySecrets = try migrateLegacySecrets(in: conversations)
        let didRefreshTokenUsage = refreshTokenUsage(in: conversations)
        if didMigrateLegacySecrets || didRefreshTokenUsage {
            try context.save()
        }
        return conversations
    }

    func createConversation(provider: LLMProvider, modelIdentifier: String? = nil) throws -> ConversationRecord {
        let conversation = ConversationRecord(
            storedTitle: try MessageEncryption.shared.encryptString("New Chat"),
            provider: provider,
            modelIdentifier: modelIdentifier
        )
        context.insert(conversation)
        try context.save()
        return conversation
    }

    func deleteConversation(_ conversation: ConversationRecord) throws {
        context.delete(conversation)
        try context.save()
    }

    func deleteAllConversations() throws {
        let all = try fetchConversations()
        for conversation in all {
            context.delete(conversation)
        }
        try context.save()
    }

    func deleteMessage(_ message: MessageRecord) throws {
        if let conversation = message.conversation {
            conversation.messages.removeAll { $0.id == message.id }
            updateMetadata(for: conversation)
        }
        context.delete(message)
        try context.save()
    }

    func appendMessage(
        role: Role,
        content: String,
        attachments: [MessageAttachment]? = nil,
        to conversation: ConversationRecord
    ) throws -> MessageRecord {
        var attachmentsData: Data? = nil
        if let attachments = attachments, !attachments.isEmpty {
            let encodedAttachments = try JSONEncoder().encode(attachments)
            attachmentsData = try MessageEncryption.shared.encryptData(encodedAttachments)
        }
        let message = MessageRecord(
            role: role,
            storedContent: try MessageEncryption.shared.encryptString(content),
            attachmentsData: attachmentsData,
            conversation: conversation
        )
        conversation.messages.append(message)
        updateMetadata(for: conversation)
        context.insert(message)
        try context.save()
        return message
    }

    func updateMessage(_ message: MessageRecord, content: String) throws {
        message.content = try MessageEncryption.shared.encryptString(content)
        if let conversation = message.conversation {
            updateMetadata(for: conversation)
        }
        try context.save()
    }

    // In-memory only update for hot streaming path — no metadata recalculation, no disk write.
    // Caller must follow up with updateMessage once streaming finishes.
    func streamUpdateMessage(_ message: MessageRecord, content: String) throws {
        message.content = try MessageEncryption.shared.encryptString(content)
    }

    func retitleConversationIfNeeded(_ conversation: ConversationRecord) throws {
        guard conversation.decryptedTitle == "New Chat" else { return }
        if let firstUserMessage = conversation.messages.first(where: { $0.role == .user })?.decryptedContent {
            let trimmed = firstUserMessage
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(50)
            conversation.title = try MessageEncryption.shared.encryptString(trimmed.isEmpty ? "New Chat" : String(trimmed))
            try context.save()
        }
    }

    func renameConversation(_ conversation: ConversationRecord, title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        conversation.title = try MessageEncryption.shared.encryptString(trimmed.isEmpty ? "New Chat" : trimmed)
        updateMetadata(for: conversation)
        try context.save()
    }

    func updateConversation(
        _ conversation: ConversationRecord,
        provider: LLMProvider? = nil,
        modelIdentifier: String? = nil,
        systemPromptOverride: String? = nil
    ) throws {
        if let provider {
            conversation.provider = provider
            if modelIdentifier == nil {
                conversation.modelIdentifier = provider.defaultModel
            }
        }

        if let modelIdentifier {
            let trimmed = modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            conversation.modelIdentifier = trimmed.isEmpty ? conversation.provider.defaultModel : trimmed
        }

        if let systemPromptOverride {
            conversation.systemPromptOverride = try MessageEncryption.shared.encryptString(systemPromptOverride)
        }

        updateMetadata(for: conversation)
        try context.save()
    }

    private func migrateLegacySecrets(in conversations: [ConversationRecord]) throws -> Bool {
        var didChange = false

        for conversation in conversations {
            if !conversation.title.isEmpty,
               !MessageEncryption.shared.isEncryptedString(conversation.title) {
                conversation.title = try MessageEncryption.shared.encryptString(conversation.title)
                didChange = true
            }

            if !conversation.systemPromptOverride.isEmpty,
               !MessageEncryption.shared.isEncryptedString(conversation.systemPromptOverride) {
                conversation.systemPromptOverride = try MessageEncryption.shared.encryptString(conversation.systemPromptOverride)
                didChange = true
            }

            for message in conversation.messages {
                if !message.content.isEmpty,
                   !MessageEncryption.shared.isEncryptedString(message.content) {
                    message.content = try MessageEncryption.shared.encryptString(message.content)
                    didChange = true
                }

                if let attachmentsData = message.attachmentsData,
                   !attachmentsData.isEmpty,
                   !MessageEncryption.shared.isEncryptedData(attachmentsData) {
                    message.attachmentsData = try MessageEncryption.shared.encryptData(attachmentsData)
                    didChange = true
                }
            }
        }

        return didChange
    }

    private func updateMetadata(for conversation: ConversationRecord) {
        conversation.updatedAt = .now
        conversation.persistedInputTokenCount = inputTokenCount(for: conversation)
        conversation.persistedOutputTokenCount = outputTokenCount(for: conversation)
    }

    private func refreshTokenUsage(in conversations: [ConversationRecord]) -> Bool {
        var didChange = false

        for conversation in conversations {
            let inputCount = inputTokenCount(for: conversation)
            let outputCount = outputTokenCount(for: conversation)
            if (conversation.persistedInputTokenCount ?? 0) != inputCount ||
                (conversation.persistedOutputTokenCount ?? 0) != outputCount {
                conversation.persistedInputTokenCount = inputCount
                conversation.persistedOutputTokenCount = outputCount
                didChange = true
            }
        }

        return didChange
    }

    private func inputTokenCount(for conversation: ConversationRecord) -> Int {
        let sortedMessages = conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })
        let nonAssistantMessages = sortedMessages.filter { $0.role != .assistant }
        let nonAssistantText = nonAssistantMessages
            .map(\.decryptedContent)
            .joined(separator: "\n")
        let systemPromptText = conversation.resolvedSystemPrompt ?? ""
        let textTokenCount = TokenFormatting.estimatedTokenCount(
            for: [nonAssistantText, systemPromptText]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        )
        let attachmentTokenCount = nonAssistantMessages.reduce(into: 0) { total, message in
            total += decodedAttachments(for: message).reduce(into: 0) { attachmentTotal, attachment in
                attachmentTotal += TokenFormatting.estimatedAttachmentTokenCount(forByteCount: attachment.data.count)
            }
        }
        return textTokenCount + attachmentTokenCount
    }

    private func outputTokenCount(for conversation: ConversationRecord) -> Int {
        let assistantText = conversation.messages
            .filter { $0.role == .assistant }
            .map(\.decryptedContent)
            .joined(separator: "\n")
        return TokenFormatting.estimatedTokenCount(for: assistantText)
    }

    private func decodedAttachments(for message: MessageRecord) -> [MessageAttachment] {
        guard let data = message.decryptedAttachmentsData,
              let attachments = try? JSONDecoder().decode([MessageAttachment].self, from: data) else {
            return []
        }
        return attachments
    }
}
