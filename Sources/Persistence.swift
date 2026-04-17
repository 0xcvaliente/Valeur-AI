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
        if try migrateLegacySecrets(in: conversations) {
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

    func updateConversation(
        _ conversation: ConversationRecord,
        provider: LLMProvider? = nil,
        modelIdentifier: String? = nil,
        systemPromptOverride: String? = nil
    ) throws {
        if let provider {
            conversation.provider = provider
            conversation.modelIdentifier = provider.defaultModel
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
    }
}
