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
        case .anthropic: "claude-sonnet-4-6"
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
                LLMModelPreset(provider: self, title: "Reasoning", subtitle: "Best for complex work", modelIdentifier: "gpt-5.4", versionLabel: "gpt-5.4", contextWindowTokens: 1_000_000, capabilities: .openAIChat),
                LLMModelPreset(provider: self, title: "Balanced", subtitle: "Fast and cost-aware", modelIdentifier: "gpt-5.4-mini", versionLabel: "gpt-5.4-mini", contextWindowTokens: 400_000, capabilities: .openAIChat),
                LLMModelPreset(provider: self, title: "Lite", subtitle: "Lowest latency and cost", modelIdentifier: "gpt-5.4-nano", versionLabel: "gpt-5.4-nano", contextWindowTokens: 400_000, capabilities: .openAIChat),
                LLMModelPreset(provider: self, title: "Pro", subtitle: "More compute for harder requests", modelIdentifier: "gpt-5.4-pro", versionLabel: "gpt-5.4-pro", contextWindowTokens: 1_050_000, capabilities: .openAIChat)
            ]
        case .anthropic:
            [
                LLMModelPreset(provider: self, title: "Opus", subtitle: "Most capable for complex tasks", modelIdentifier: "claude-opus-4-7", versionLabel: "4.7", contextWindowTokens: 1_000_000, capabilities: .anthropicChat),
                LLMModelPreset(provider: self, title: "Sonnet", subtitle: "Best balance of speed and quality", modelIdentifier: "claude-sonnet-4-6", versionLabel: "4.6", contextWindowTokens: 1_000_000, capabilities: .anthropicChat),
                LLMModelPreset(provider: self, title: "Haiku", subtitle: "Fastest option for lightweight tasks", modelIdentifier: "claude-haiku-4-5", versionLabel: "4.5", contextWindowTokens: 200_000, capabilities: .anthropicChat)
            ]
        case .gemini:
            [
                LLMModelPreset(provider: self, title: "Pro", subtitle: "Best for complex reasoning", modelIdentifier: "gemini-2.5-pro", versionLabel: "2.5", contextWindowTokens: 1_048_576, capabilities: .geminiChat),
                LLMModelPreset(provider: self, title: "Flash", subtitle: "Best price-performance balance", modelIdentifier: "gemini-2.5-flash", versionLabel: "2.5", contextWindowTokens: 1_048_576, capabilities: .geminiChat),
                LLMModelPreset(provider: self, title: "Flash-Lite", subtitle: "Fastest and most cost efficient", modelIdentifier: "gemini-2.5-flash-lite", versionLabel: "2.5", contextWindowTokens: 1_048_576, capabilities: .geminiChat)
            ]
        }
    }

    func preset(for modelIdentifier: String) -> LLMModelPreset? {
        let normalized = normalizedModelIdentifier(modelIdentifier)
        return presets.first(where: { $0.modelIdentifier == normalized })
    }

    func versionLabel(for modelIdentifier: String) -> String {
        preset(for: modelIdentifier)?.versionLabel ?? normalizedModelIdentifier(modelIdentifier)
    }

    func contextWindowTokens(for modelIdentifier: String) -> Int {
        preset(for: modelIdentifier)?.contextWindowTokens ?? defaultContextWindowTokens
    }

    func capabilities(for modelIdentifier: String) -> ModelCapabilities {
        preset(for: modelIdentifier)?.capabilities ?? .baselineChat
    }

    func imageGenerationModel(for modelIdentifier: String) -> String? {
        capabilities(for: modelIdentifier).imageGenerationModelIdentifier
    }

    var defaultContextWindowTokens: Int {
        preset(for: defaultModel)?.contextWindowTokens ?? 1_000_000
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
        case .anthropic:
            switch trimmed {
            case "claude-3-5-haiku-latest", "claude-3-5-haiku-20241022":
                return "claude-haiku-4-5"
            case "claude-3-7-sonnet-latest", "claude-sonnet-4-5", "claude-sonnet-4-6-20251001":
                return "claude-sonnet-4-6"
            case "claude-opus-4-6":
                return "claude-opus-4-7"
            default:
                return trimmed
            }
        case .gemini:
            switch trimmed {
            case "gemini-2.0-flash", "gemini-2.0-flash-exp":
                return "gemini-2.5-flash"
            case "gemini-1.5-pro", "gemini-1.5-pro-latest":
                return "gemini-2.5-pro"
            default:
                return trimmed
            }
        }
    }
}

struct ModelCapabilities: Hashable {
    let supportsVisionInput: Bool
    let supportsDocumentInput: Bool
    let imageGenerationModelIdentifier: String?
    let supportsWebSearch: Bool
    let supportsStructuredArtifacts: Bool

    var supportsImageGeneration: Bool {
        imageGenerationModelIdentifier != nil
    }

    static let baselineChat = ModelCapabilities(
        supportsVisionInput: false,
        supportsDocumentInput: false,
        imageGenerationModelIdentifier: nil,
        supportsWebSearch: false,
        supportsStructuredArtifacts: true
    )

    static let openAIChat = ModelCapabilities(
        supportsVisionInput: true,
        supportsDocumentInput: true,
        imageGenerationModelIdentifier: "gpt-image-1",
        supportsWebSearch: true,
        supportsStructuredArtifacts: true
    )

    static let anthropicChat = ModelCapabilities(
        supportsVisionInput: true,
        supportsDocumentInput: true,
        imageGenerationModelIdentifier: nil,
        supportsWebSearch: false,
        supportsStructuredArtifacts: true
    )

    static let geminiChat = ModelCapabilities(
        supportsVisionInput: true,
        supportsDocumentInput: true,
        imageGenerationModelIdentifier: nil,
        supportsWebSearch: true,
        supportsStructuredArtifacts: true
    )
}

struct LLMModelPreset: Identifiable, Hashable {
    let provider: LLMProvider
    let title: String
    let subtitle: String
    let modelIdentifier: String
    let versionLabel: String
    let contextWindowTokens: Int
    let capabilities: ModelCapabilities

    var id: String {
        "\(provider.rawValue)-\(modelIdentifier)"
    }

    var selectorText: String {
        "\(provider.selectorTitle) \(title)"
    }

    var contextWindowLabel: String {
        TokenFormatting.windowLabel(contextWindowTokens)
    }

    var supportsVisionInput: Bool {
        capabilities.supportsVisionInput
    }

    var supportsDocumentInput: Bool {
        capabilities.supportsDocumentInput
    }

    var supportsImageGeneration: Bool {
        capabilities.supportsImageGeneration
    }

    var imageGenerationModelIdentifier: String? {
        capabilities.imageGenerationModelIdentifier
    }

    var supportsWebSearch: Bool {
        capabilities.supportsWebSearch
    }
}

enum Role: String, Codable, Sendable {
    case system
    case user
    case assistant
}

struct MessageAttachment: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let data: Data
    let mimeType: String
    
    init(id: UUID = UUID(), data: Data, mimeType: String) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
    }
}

enum ComposerMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case chat
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat:
            return "Chat"
        case .image:
            return "Image"
        }
    }

    var icon: String {
        switch self {
        case .chat:
            return "text.bubble"
        case .image:
            return "photo"
        }
    }
}

enum ImageGenerationSize: String, CaseIterable, Identifiable, Codable, Sendable {
    case square = "1024x1024"
    case portrait = "1024x1536"
    case landscape = "1536x1024"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square:
            return "Square"
        case .portrait:
            return "Portrait"
        case .landscape:
            return "Landscape"
        }
    }

    var icon: String {
        switch self {
        case .square:
            return "square"
        case .portrait:
            return "rectangle.portrait"
        case .landscape:
            return "rectangle"
        }
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

struct ImageGenerationRequest: Sendable {
    let prompt: String
    let model: String
    let size: ImageGenerationSize
}

struct ImageGenerationResponse: Sendable {
    let images: [MessageAttachment]
    let revisedPrompt: String?
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
    var persistedInputTokenCount: Int
    var persistedOutputTokenCount: Int
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
        persistedInputTokenCount: Int = 0,
        persistedOutputTokenCount: Int = 0,
        messages: [MessageRecord] = []
    ) {
        self.id = id
        self.title = storedTitle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerRawValue = provider.rawValue
        self.modelIdentifier = modelIdentifier ?? provider.defaultModel
        self.systemPromptOverride = storedSystemPromptOverride
        self.persistedInputTokenCount = persistedInputTokenCount
        self.persistedOutputTokenCount = persistedOutputTokenCount
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

    var persistedTotalTokenCount: Int {
        persistedInputTokenCount + persistedOutputTokenCount
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
