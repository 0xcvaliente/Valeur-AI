import Foundation
import SwiftData

enum WorkspaceBlockKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case text
    case table
    case chart
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            return "Text"
        case .table:
            return "Table"
        case .chart:
            return "Chart"
        case .image:
            return "Image"
        }
    }

    var icon: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .table:
            return "tablecells"
        case .chart:
            return "chart.bar"
        case .image:
            return "photo"
        }
    }
}

enum WorkspaceRevisionApplyMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case replace
    case duplicate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replace:
            return "Replace"
        case .duplicate:
            return "Duplicate"
        }
    }

    var subtitle: String {
        switch self {
        case .replace:
            return "Update the current block and keep the previous version in history."
        case .duplicate:
            return "Keep the current block and insert the revised result as a new block."
        }
    }
}

struct WorkspaceImagePayload: Codable, Equatable, Sendable {
    var caption: String
    var remoteURLString: String?

    var remoteURL: URL? {
        guard let remoteURLString,
              let url = URL(string: remoteURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return url
    }
}

@Model
final class WorkspaceRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var sourceConversationID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \WorkspaceBlockRecord.workspace)
    var blocks: [WorkspaceBlockRecord]

    init(
        id: UUID = UUID(),
        storedTitle: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sourceConversationID: UUID? = nil,
        blocks: [WorkspaceBlockRecord] = []
    ) {
        self.id = id
        self.title = storedTitle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceConversationID = sourceConversationID
        self.blocks = blocks
    }

    var decryptedTitle: String {
        MessageEncryption.shared.decryptString(title)
    }
}

@Model
final class WorkspaceBlockRecord {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var sortOrder: Int
    var content: String
    @Attribute(.externalStorage) var attachmentsData: Data?
    @Relationship(deleteRule: .cascade, inverse: \WorkspaceBlockRevisionRecord.block)
    var revisions: [WorkspaceBlockRevisionRecord]
    var workspace: WorkspaceRecord?

    init(
        id: UUID = UUID(),
        kind: WorkspaceBlockKind,
        sortOrder: Int,
        storedContent: String,
        attachmentsData: Data? = nil,
        revisions: [WorkspaceBlockRevisionRecord] = [],
        workspace: WorkspaceRecord? = nil
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.sortOrder = sortOrder
        self.content = storedContent
        self.attachmentsData = attachmentsData
        self.revisions = revisions
        self.workspace = workspace
    }

    var kind: WorkspaceBlockKind {
        get { WorkspaceBlockKind(rawValue: kindRawValue) ?? .text }
        set { kindRawValue = newValue.rawValue }
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

@Model
final class WorkspaceBlockRevisionRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var instruction: String
    var providerRawValue: String
    var modelIdentifier: String
    var applyModeRawValue: String
    var content: String
    @Attribute(.externalStorage) var attachmentsData: Data?
    var block: WorkspaceBlockRecord?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        storedInstruction: String,
        providerRawValue: String = "",
        modelIdentifier: String = "",
        applyMode: WorkspaceRevisionApplyMode = .replace,
        storedContent: String,
        attachmentsData: Data? = nil,
        block: WorkspaceBlockRecord? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.instruction = storedInstruction
        self.providerRawValue = providerRawValue
        self.modelIdentifier = modelIdentifier
        self.applyModeRawValue = applyMode.rawValue
        self.content = storedContent
        self.attachmentsData = attachmentsData
        self.block = block
    }

    var applyMode: WorkspaceRevisionApplyMode {
        get { WorkspaceRevisionApplyMode(rawValue: applyModeRawValue) ?? .replace }
        set { applyModeRawValue = newValue.rawValue }
    }

    var provider: LLMProvider? {
        LLMProvider(rawValue: providerRawValue)
    }

    var decryptedInstruction: String {
        MessageEncryption.shared.decryptString(instruction)
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
