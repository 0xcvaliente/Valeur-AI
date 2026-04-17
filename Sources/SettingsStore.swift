import Foundation
import Combine
import SwiftUI
import PDFKit

@MainActor
final class SettingsStore: ObservableObject {
    private let keychain: KeychainService
    private let defaults: UserDefaults

    @Published var defaultProvider: LLMProvider {
        didSet {
            defaults.set(defaultProvider.rawValue, forKey: Keys.defaultProvider)
            ensureSelectedModel(for: defaultProvider)
        }
    }

    @Published private var selectedModelsByProvider: [String: String] {
        didSet { defaults.set(selectedModelsByProvider, forKey: Keys.selectedModelsByProvider) }
    }

    @Published var systemPrompt: String {
        didSet {
            try? keychain.save(systemPrompt, for: Keys.Keychain.systemPrompt)
            defaults.removeObject(forKey: Keys.Legacy.systemPrompt)
        }
    }

    @Published var customInstructions: String {
        didSet {
            try? keychain.save(customInstructions, for: Keys.Keychain.customInstructions)
            defaults.removeObject(forKey: Keys.Legacy.customInstructions)
        }
    }

    @Published var userName: String {
        didSet {
            try? keychain.save(userName, for: Keys.Keychain.userName)
            defaults.removeObject(forKey: Keys.Legacy.userName)
        }
    }

    @Published private(set) var memoryDocumentName: String {
        didSet { defaults.set(memoryDocumentName, forKey: Keys.memoryDocumentName) }
    }

    @Published private(set) var memoryDocumentContent: String {
        didSet {
            if memoryDocumentContent.isEmpty {
                try? keychain.delete(account: Keys.Keychain.memoryDocumentContent)
            } else {
                try? keychain.save(memoryDocumentContent, for: Keys.Keychain.memoryDocumentContent)
            }
            defaults.removeObject(forKey: Keys.Legacy.memoryDocumentContent)
        }
    }

    @Published var appAppearance: AppAppearance {
        didSet { defaults.set(appAppearance.rawValue, forKey: Keys.appAppearance) }
    }

    @Published var appFontSize: AppFontSize {
        didSet { defaults.set(appFontSize.rawValue, forKey: Keys.appFontSize) }
    }

    @Published var webSearchEnabled: Bool {
        didSet { defaults.set(webSearchEnabled, forKey: Keys.webSearchEnabled) }
    }

    init(keychain: KeychainService, defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults
        let initialDefaultProvider = LLMProvider(rawValue: defaults.string(forKey: Keys.defaultProvider) ?? "") ?? .openAI
        self.defaultProvider = initialDefaultProvider
        self.selectedModelsByProvider = Self.loadSelectedModels(defaults: defaults, defaultProvider: initialDefaultProvider)
        self.systemPrompt = Self.migrateToKeychain(keychain: keychain, account: Keys.Keychain.systemPrompt, legacyKey: Keys.Legacy.systemPrompt, defaults: defaults)
        self.customInstructions = Self.migrateToKeychain(keychain: keychain, account: Keys.Keychain.customInstructions, legacyKey: Keys.Legacy.customInstructions, defaults: defaults)
        self.userName = Self.migrateToKeychain(keychain: keychain, account: Keys.Keychain.userName, legacyKey: Keys.Legacy.userName, defaults: defaults)
        self.memoryDocumentName = defaults.string(forKey: Keys.memoryDocumentName) ?? ""
        self.memoryDocumentContent = Self.migrateToKeychain(keychain: keychain, account: Keys.Keychain.memoryDocumentContent, legacyKey: Keys.Legacy.memoryDocumentContent, defaults: defaults)
        self.appAppearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appAppearance) ?? "") ?? .light
        self.appFontSize = AppFontSize(rawValue: defaults.string(forKey: Keys.appFontSize) ?? "") ?? .normal
        self.webSearchEnabled = defaults.object(forKey: Keys.webSearchEnabled) as? Bool ?? false
        ensureSelectedModel(for: defaultProvider)
    }

    var selectedModel: String {
        get { selectedModel(for: defaultProvider) }
        set { setSelectedModel(newValue, for: defaultProvider) }
    }

    func selectedModel(for provider: LLMProvider) -> String {
        let trimmed = selectedModelsByProvider[provider.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return provider.normalizedModelIdentifier(trimmed)
    }

    func setSelectedModel(_ value: String, for provider: LLMProvider) {
        let resolved = provider.normalizedModelIdentifier(value)
        if selectedModelsByProvider[provider.rawValue] == resolved {
            return
        }

        var updated = selectedModelsByProvider
        updated[provider.rawValue] = resolved
        selectedModelsByProvider = updated
    }

    func apiKey(for provider: LLMProvider) -> String {
        (try? keychain.read(account: keyAccount(for: provider))) ?? ""
    }

    func setAPIKey(_ value: String, for provider: LLMProvider) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try keychain.delete(account: keyAccount(for: provider))
        } else {
            try keychain.save(trimmed, for: keyAccount(for: provider))
        }
    }

    private func keyAccount(for provider: LLMProvider) -> String {
        "api-key-\(provider.rawValue)"
    }

    var hasMemoryDocument: Bool {
        !memoryDocumentContent.isEmpty
    }

    var memoryDocumentSummary: String? {
        guard hasMemoryDocument else { return nil }
        let characterCount = memoryDocumentContent.count
        let label = characterCount >= 1_000 ? "\(characterCount / 1_000)K characters" : "\(characterCount) characters"
        return "\(memoryDocumentName) • \(label)"
    }

    func setMemoryDocument(from url: URL) throws {
        let extracted = try Self.extractDocumentText(from: url)
        let normalized = Self.normalizeMemoryText(extracted)
        guard !normalized.isEmpty else {
            throw PersonalizationError.emptyDocument
        }

        memoryDocumentName = url.lastPathComponent
        memoryDocumentContent = normalized
    }

    func clearMemoryDocument() {
        memoryDocumentName = ""
        memoryDocumentContent = ""
    }

    func composedSystemPrompt(conversationSystemPrompt: String?) -> String? {
        var sections: [String] = []

        let basePrompt = (conversationSystemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? conversationSystemPrompt!.trimmingCharacters(in: .whitespacesAndNewlines)
            : systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !basePrompt.isEmpty {
            sections.append(basePrompt)
        }

        let instructions = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !instructions.isEmpty {
            sections.append("""
            Personalization Instructions:
            \(instructions)
            """)
        }

        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            sections.append("""
            User Profile:
            The user's name is \(name).
            """)
        }

        let memory = memoryDocumentContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !memory.isEmpty {
            sections.append("""
            Memory Document:
            Use this user-provided reference when it is relevant to the request. If it is not relevant, ignore it.

            \(memory)
            """)
        }

        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    private enum Keys {
        static let defaultProvider = "settings.defaultProvider"
        static let selectedModelsByProvider = "settings.selectedModelsByProvider"
        static let selectedModel = "settings.selectedModel"
        static let memoryDocumentName = "settings.memoryDocumentName"
        static let appAppearance = "settings.appAppearance"
        static let appFontSize = AppFontSize.defaultsKey
        static let webSearchEnabled = "settings.webSearchEnabled"

        enum Keychain {
            static let systemPrompt = "settings-system-prompt"
            static let customInstructions = "settings-custom-instructions"
            static let userName = "settings-user-name"
            static let memoryDocumentContent = "settings-memory-document-content"
        }

        enum Legacy {
            static let systemPrompt = "settings.systemPrompt"
            static let customInstructions = "settings.customInstructions"
            static let userName = "settings.userName"
            static let memoryDocumentContent = "settings.memoryDocumentContent"
        }
    }

    private static func migrateToKeychain(keychain: KeychainService, account: String, legacyKey: String, defaults: UserDefaults) -> String {
        if let value = try? keychain.read(account: account) {
            return value
        }
        let legacy = defaults.string(forKey: legacyKey) ?? ""
        if !legacy.isEmpty {
            try? keychain.save(legacy, for: account)
            defaults.removeObject(forKey: legacyKey)
        }
        return legacy
    }

    private func ensureSelectedModel(for provider: LLMProvider) {
        if selectedModelsByProvider[provider.rawValue] == nil {
            setSelectedModel(provider.defaultModel, for: provider)
        }
    }

    private static func loadSelectedModels(defaults: UserDefaults, defaultProvider: LLMProvider) -> [String: String] {
        let stored = defaults.dictionary(forKey: Keys.selectedModelsByProvider) as? [String: String] ?? [:]
        let legacySelectedModel = defaults.string(forKey: Keys.selectedModel)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var resolved: [String: String] = [:]
        for provider in LLMProvider.allCases {
            let storedValue = stored[provider.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let storedValue, !storedValue.isEmpty {
                resolved[provider.rawValue] = provider.normalizedModelIdentifier(storedValue)
            } else if provider == defaultProvider, let legacySelectedModel, !legacySelectedModel.isEmpty {
                resolved[provider.rawValue] = provider.normalizedModelIdentifier(legacySelectedModel)
            } else {
                resolved[provider.rawValue] = provider.defaultModel
            }
        }

        return resolved
    }

    private static func extractDocumentText(from url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url), let text = document.string else {
                throw PersonalizationError.unsupportedDocument
            }
            return text
        }

        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }

        let data = try Data(contentsOf: url)
        for encoding in [String.Encoding.utf8, .unicode, .ascii, .isoLatin1] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        throw PersonalizationError.unsupportedDocument
    }

    private static func normalizeMemoryText(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(collapsed.prefix(16_000))
        return limited
    }
}

enum PersonalizationError: LocalizedError {
    case emptyDocument
    case unsupportedDocument

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "The selected document did not contain readable text."
        case .unsupportedDocument:
            return "This document type is not supported yet. Use a text, markdown, JSON, or PDF file."
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case light
    case marineBlue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .marineBlue: "Marine Blue"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .marineBlue: .dark
        }
    }
}

enum AppFontSize: String, CaseIterable, Identifiable {
    case extraSmall
    case small
    case normal
    case big

    static let defaultsKey = "settings.appFontSize"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .extraSmall: "Extra Small"
        case .small: "Small"
        case .normal: "Normal"
        case .big: "Big"
        }
    }

    var scale: CGFloat {
        switch self {
        case .extraSmall: 0.86
        case .small: 0.94
        case .normal: 1.0
        case .big: 1.12
        }
    }
}
