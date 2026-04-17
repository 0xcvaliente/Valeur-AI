import Foundation
import SwiftData

enum LLMProvider: String, CaseIterable, Codable, Identifiable {
    case openAI
    case anthropic
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Google Gemini"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-5.4-mini"
        case .anthropic: "claude-3-7-sonnet-latest"
        case .gemini: "gemini-2.5-flash"
        }
    }

    var apiKeyLabel: String {
        "\(displayName) API Key"
    }

    var selectorTitle: String {
        switch self {
        case .openAI: "ChatGPT"
        case .anthropic: "Claude"
        case .gemini: "Gemini"
        }
    }

    var presets: [LLMModelPreset] {
        switch self {
        case .openAI:
            [
                LLMModelPreset(provider: self, title: "Instant", subtitle: "Fast everyday responses", modelIdentifier: "gpt-5.4-mini"),
                LLMModelPreset(provider: self, title: "Thinking", subtitle: "Stronger reasoning for harder tasks", modelIdentifier: "gpt-5.4"),
                LLMModelPreset(provider: self, title: "Pro", subtitle: "Highest precision, slower responses", modelIdentifier: "gpt-5.4-pro")
            ]
        case .anthropic:
            [
                LLMModelPreset(provider: self, title: "Instant", subtitle: "Quick Claude replies", modelIdentifier: "claude-3-5-haiku-latest"),
                LLMModelPreset(provider: self, title: "Thinking", subtitle: "Longer reasoning with Sonnet", modelIdentifier: "claude-3-7-sonnet-latest")
            ]
        case .gemini:
            [
                LLMModelPreset(provider: self, title: "Instant", subtitle: "Fast multimodal responses", modelIdentifier: "gemini-2.5-flash"),
                LLMModelPreset(provider: self, title: "Thinking", subtitle: "Deeper answers with Pro", modelIdentifier: "gemini-2.5-pro")
            ]
        }
    }

    func preset(for modelIdentifier: String) -> LLMModelPreset? {
        let normalized = normalizedModelIdentifier(modelIdentifier)
        return presets.first(where: { $0.modelIdentifier == normalized })
    }

    func normalizedModelIdentifier(_ modelIdentifier: String) -> String {
        let trimmed = modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultModel }

        switch self {
        case .openAI:
            switch trimmed {
            case "gpt-4.1-mini", "gpt-5-nano-2025-08-07":
                return "gpt-5.4-mini"
            case "gpt-4.1":
                return "gpt-5.4"
            case "gpt-5":
                return "gpt-5.4-pro"
            default:
                return trimmed
            }
        case .anthropic, .gemini:
            return trimmed
        }
    }
}

struct LLMModelPreset: Identifiable, Hashable {
    let provider: LLMProvider
    let title: String
    let subtitle: String
    let modelIdentifier: String

    var id: String {
        "\(provider.rawValue)-\(modelIdentifier)"
    }

    var selectorText: String {
        "\(provider.selectorTitle) \(title)"
    }
}

enum Role: String, Codable {
    case system
    case user
    case assistant
}

struct MessageAttachment: Codable, Equatable, Identifiable {
    let id: UUID
    let data: Data
    let mimeType: String
    
    init(id: UUID = UUID(), data: Data, mimeType: String) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
    }
}

struct ChatMessagePayload: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    var attachments: [MessageAttachment]?
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, attachments: [MessageAttachment]? = nil, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.attachments = attachments
        self.createdAt = createdAt
    }
}

struct ChatRequest: Sendable {
    let messages: [ChatMessagePayload]
    let systemPrompt: String?
    let model: String
    let allowsWebSearch: Bool
}

enum LLMStreamEvent: Sendable {
    case started
    case token(String)
    case status(String)
    case finished
}

@Model
final class ConversationRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var providerRawValue: String
    var modelIdentifier: String
    var systemPromptOverride: String
    @Relationship(deleteRule: .cascade, inverse: \MessageRecord.conversation)
    var messages: [MessageRecord]

    init(
        id: UUID = UUID(),
        storedTitle: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        provider: LLMProvider = .openAI,
        modelIdentifier: String? = nil,
        storedSystemPromptOverride: String = "",
        messages: [MessageRecord] = []
    ) {
        self.id = id
        self.title = storedTitle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerRawValue = provider.rawValue
        self.modelIdentifier = modelIdentifier ?? provider.defaultModel
        self.systemPromptOverride = storedSystemPromptOverride
        self.messages = messages
    }

    var provider: LLMProvider {
        get { LLMProvider(rawValue: providerRawValue) ?? .openAI }
        set { providerRawValue = newValue.rawValue }
    }

    var decryptedTitle: String {
        MessageEncryption.shared.decryptString(title)
    }

    var resolvedSystemPrompt: String? {
        let trimmed = MessageEncryption.shared
            .decryptString(systemPromptOverride)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@Model
final class MessageRecord {
    @Attribute(.unique) var id: UUID
    var roleRawValue: String
    var content: String
    @Attribute(.externalStorage) var attachmentsData: Data?
    var createdAt: Date
    var conversation: ConversationRecord?

    init(
        id: UUID = UUID(),
        role: Role,
        storedContent: String,
        attachmentsData: Data? = nil,
        createdAt: Date = .now,
        conversation: ConversationRecord? = nil
    ) {
        self.id = id
        self.roleRawValue = role.rawValue
        self.content = storedContent
        self.attachmentsData = attachmentsData
        self.createdAt = createdAt
        self.conversation = conversation
    }

    var role: Role {
        get { Role(rawValue: roleRawValue) ?? .assistant }
        set { roleRawValue = newValue.rawValue }
    }

    var decryptedContent: String {
        MessageEncryption.shared.decryptString(content)
    }

    var decryptedAttachmentsData: Data? {
        guard let attachmentsData else { return nil }
        let decrypted = MessageEncryption.shared.decryptData(attachmentsData)
        return decrypted.isEmpty ? nil : decrypted
    }
}
