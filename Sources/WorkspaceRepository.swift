import AppKit
import Combine
import Foundation
import SwiftData

struct WorkspaceBlockSeed: Sendable {
    let kind: WorkspaceBlockKind
    let content: String
    let attachmentsData: Data?
}

enum WorkspaceRevisionError: LocalizedError {
    case unsupportedBlockKind
    case emptyInstruction
    case emptyResponse
    case invalidTable
    case invalidChart

    var errorDescription: String? {
        switch self {
        case .unsupportedBlockKind:
            return "AI revision is currently available for text, table, and chart blocks only."
        case .emptyInstruction:
            return "Enter a revision instruction before running AI iteration."
        case .emptyResponse:
            return "The AI returned an empty revision. Try a more specific instruction."
        case .invalidTable:
            return "The AI returned an invalid table payload. Try again with a more specific table instruction."
        case .invalidChart:
            return "The AI returned an invalid chart payload. Try again with a more specific chart instruction."
        }
    }
}

enum WorkspaceImportError: LocalizedError {
    case invalidTextFile
    case invalidCSV
    case invalidChartJSON
    case invalidImageFile

    var errorDescription: String? {
        switch self {
        case .invalidTextFile:
            return "The selected file couldn't be read as text."
        case .invalidCSV:
            return "The selected CSV file couldn't be parsed into a table."
        case .invalidChartJSON:
            return "The selected JSON file isn't a valid chart specification."
        case .invalidImageFile:
            return "The selected file isn't a supported image."
        }
    }
}

enum WorkspaceAIRevisionParser {
    static func normalizedText(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func unwrappedCodeFence(_ rawValue: String) -> String {
        let trimmed = normalizedText(rawValue)
        guard trimmed.hasPrefix("```") else { return trimmed }

        let lines = trimmed.components(separatedBy: "\n")
        guard lines.count >= 2 else { return trimmed }
        guard let closingFenceIndex = lines.lastIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "```" }) else {
            return trimmed
        }

        let bodyLines = Array(lines.dropFirst().prefix(closingFenceIndex - 1))
        return bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func jsonObjectString(from rawValue: String) -> String? {
        let unwrapped = unwrappedCodeFence(rawValue)
        guard let start = unwrapped.firstIndex(of: "{"),
              let end = unwrapped.lastIndex(of: "}") else {
            return nil
        }
        return String(unwrapped[start...end])
    }
}

enum WorkspaceAIRevisionComposer {
    static func request(
        for block: WorkspaceBlockRecord,
        instruction: String,
        provider: LLMProvider,
        modelIdentifier: String,
        settingsStore: SettingsStore
    ) throws -> ChatRequest {
        let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstruction.isEmpty else {
            throw WorkspaceRevisionError.emptyInstruction
        }

        let blockPrompt = try userPrompt(for: block, instruction: trimmedInstruction)
        let revisionSystemPrompt = """
        You are revising a structured workspace block inside a desktop editor.
        Follow the instruction precisely.
        Return only the revised block payload.
        Never include conversational framing such as 'Here is the revised version'.
        """
        let settingsPrompt = settingsStore.composedSystemPrompt(conversationSystemPrompt: nil)
        let systemPrompt = [revisionSystemPrompt, settingsPrompt]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        return ChatRequest(
            messages: [
                ChatMessagePayload(role: .user, content: blockPrompt)
            ],
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
            model: modelIdentifier,
            allowsWebSearch: false
        )
    }

    static func revisedSeed(from response: String, originalBlock: WorkspaceBlockRecord) throws -> WorkspaceBlockSeed {
        let cleanedResponse = WorkspaceAIRevisionParser.normalizedText(response)
        guard !cleanedResponse.isEmpty else {
            throw WorkspaceRevisionError.emptyResponse
        }

        switch originalBlock.kind {
        case .text:
            let markdown = WorkspaceAIRevisionParser.unwrappedCodeFence(cleanedResponse)
            let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw WorkspaceRevisionError.emptyResponse
            }
            return WorkspaceBlockSeed(kind: .text, content: trimmed, attachmentsData: originalBlock.decryptedAttachmentsData)
        case .table:
            let payload = WorkspaceAIRevisionParser.jsonObjectString(from: cleanedResponse)
                ?? WorkspaceAIRevisionParser.unwrappedCodeFence(cleanedResponse)
            guard let table = WorkspaceSeedFactory.decodeTable(from: payload) else {
                throw WorkspaceRevisionError.invalidTable
            }
            return WorkspaceBlockSeed(kind: .table, content: WorkspaceSeedFactory.encodedTable(table), attachmentsData: nil)
        case .chart:
            let payload = WorkspaceAIRevisionParser.jsonObjectString(from: cleanedResponse)
                ?? WorkspaceAIRevisionParser.unwrappedCodeFence(cleanedResponse)
            guard let chart = WorkspaceSeedFactory.decodeChart(from: payload) else {
                throw WorkspaceRevisionError.invalidChart
            }
            return WorkspaceBlockSeed(kind: .chart, content: WorkspaceSeedFactory.encodedChart(chart), attachmentsData: nil)
        case .image:
            throw WorkspaceRevisionError.unsupportedBlockKind
        }
    }

    private static func userPrompt(for block: WorkspaceBlockRecord, instruction: String) throws -> String {
        switch block.kind {
        case .text:
            return """
            Revise this markdown text block.

            Instruction:
            \(instruction)

            Current markdown:
            \(block.decryptedContent)

            Return only the revised markdown text.
            Do not wrap the answer in code fences.
            """
        case .table:
            return """
            Revise this table block.

            Instruction:
            \(instruction)

            Current table JSON:
            \(block.decryptedContent)

            Return only valid JSON, with no prose and no markdown fences, matching this exact schema:
            {
              "headers": ["Column 1", "Column 2"],
              "alignments": ["leading", "center", "trailing"],
              "rows": [["A", "B"]]
            }
            Ensure the number of alignments matches the number of headers and every row has the same number of cells as the headers.
            """
        case .chart:
            return """
            Revise this chart specification.

            Instruction:
            \(instruction)

            Current chart JSON:
            \(block.decryptedContent)

            Return only valid JSON, with no prose and no markdown fences, matching this exact schema:
            {
              "type": "bar",
              "title": "Optional title",
              "subtitle": "Optional subtitle",
              "xLabel": "Optional x axis label",
              "yLabel": "Optional y axis label",
              "data": [
                { "label": "Item", "value": 0, "series": "Optional" }
              ]
            }
            The type must be one of: bar, line, area.
            """
        case .image:
            throw WorkspaceRevisionError.unsupportedBlockKind
        }
    }
}

enum WorkspaceSeedFactory {
    static func seeds(from content: String, attachments: [MessageAttachment]) -> [WorkspaceBlockSeed] {
        var seeds: [WorkspaceBlockSeed] = attachments.compactMap { attachment in
            if attachment.mimeType.hasPrefix("image/") {
                return imageSeed(payload: WorkspaceImagePayload(caption: "", remoteURLString: nil), imageData: attachment.data)
            }

            if attachment.mimeType == "application/pdf" {
                return textSeed("Attached PDF document")
            }

            return nil
        }

        for block in MarkdownBlock.parse(content) {
            switch block.kind {
            case .markdown(let markdown):
                seeds.append(contentsOf: markdownSeeds(from: markdown))
            case .chart(let spec):
                seeds.append(chartSeed(spec))
            case .code(let language, let code):
                let label = (language?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? language! : ""
                let fence = label.isEmpty ? "```\n\(code)\n```" : "```\(label)\n\(code)\n```"
                seeds.append(textSeed(fence))
            }
        }

        if seeds.isEmpty {
            seeds.append(textSeed(content))
        }

        return seeds
    }

    static func workspaceTitle(for content: String, fallback: String?) -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            let flattened = trimmedContent.replacingOccurrences(of: "\n", with: " ")
            return String(flattened.prefix(44))
        }

        let trimmedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedFallback.isEmpty ? "Workspace" : "\(trimmedFallback) Workspace"
    }

    static func defaultSeed(for kind: WorkspaceBlockKind) -> WorkspaceBlockSeed {
        switch kind {
        case .text:
            return textSeed("# Draft\n\nStart writing here.")
        case .table:
            return tableSeed(
                MarkdownTable(
                    headers: ["Column 1", "Column 2"],
                    alignments: [.leading, .leading],
                    rows: [["", ""], ["", ""]]
                )
            )
        case .chart:
            return chartSeed(
                MarkdownChartSpec(
                    type: .bar,
                    title: "Chart Title",
                    subtitle: "Edit the JSON to reshape this chart.",
                    xLabel: "Category",
                    yLabel: "Value",
                    data: [
                        MarkdownChartPoint(label: "A", value: 12, series: nil),
                        MarkdownChartPoint(label: "B", value: 18, series: nil),
                        MarkdownChartPoint(label: "C", value: 9, series: nil)
                    ]
                )
            )
        case .image:
            return imageSeed(payload: WorkspaceImagePayload(caption: "", remoteURLString: nil), imageData: nil)
        }
    }

    static func encodedTable(_ table: MarkdownTable) -> String {
        encodedString(table)
    }

    static func encodedChart(_ spec: MarkdownChartSpec) -> String {
        encodedString(spec)
    }

    static func encodedImagePayload(_ payload: WorkspaceImagePayload) -> String {
        encodedString(payload)
    }

    static func decodeTable(from content: String) -> MarkdownTable? {
        decode(MarkdownTable.self, from: content)
    }

    static func decodeChart(from content: String) -> MarkdownChartSpec? {
        decode(MarkdownChartSpec.self, from: content)
    }

    static func decodeImagePayload(from content: String) -> WorkspaceImagePayload {
        decode(WorkspaceImagePayload.self, from: content) ?? WorkspaceImagePayload(caption: "", remoteURLString: nil)
    }

    private static func markdownSeeds(from markdown: String) -> [WorkspaceBlockSeed] {
        var seeds: [WorkspaceBlockSeed] = []
        var textFragments: [String] = []

        func flushText() {
            let text = textFragments
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                textFragments.removeAll(keepingCapacity: true)
                return
            }
            seeds.append(textSeed(text))
            textFragments.removeAll(keepingCapacity: true)
        }

        for block in MarkdownLayoutBlock.parse(markdown) {
            switch block.kind {
            case .remoteImage(let remoteImage):
                flushText()
                seeds.append(imageSeed(
                    payload: WorkspaceImagePayload(caption: remoteImage.altText, remoteURLString: remoteImage.url.absoluteString),
                    imageData: nil
                ))
            case .table(let table):
                flushText()
                seeds.append(tableSeed(table))
            default:
                textFragments.append(markdownString(for: block))
            }
        }

        flushText()
        return seeds
    }

    private static func markdownString(for block: MarkdownLayoutBlock) -> String {
        switch block.kind {
        case .heading(let level, let text):
            return "\(String(repeating: "#", count: level)) \(text)"
        case .paragraph(let text):
            return text
        case .quote(let text):
            return text
                .components(separatedBy: "\n")
                .map { "> \($0)" }
                .joined(separator: "\n")
        case .divider:
            return "---"
        case .list(let items, let isOrdered):
            return items.enumerated().map { index, item in
                if isOrdered {
                    return "\(item.ordinal ?? (index + 1)). \(item.text)"
                }
                return "- \(item.text)"
            }
            .joined(separator: "\n")
        case .remoteImage, .table:
            return ""
        }
    }

    private static func textSeed(_ markdown: String) -> WorkspaceBlockSeed {
        WorkspaceBlockSeed(kind: .text, content: markdown, attachmentsData: nil)
    }

    private static func tableSeed(_ table: MarkdownTable) -> WorkspaceBlockSeed {
        WorkspaceBlockSeed(kind: .table, content: encodedTable(table), attachmentsData: nil)
    }

    private static func chartSeed(_ spec: MarkdownChartSpec) -> WorkspaceBlockSeed {
        WorkspaceBlockSeed(kind: .chart, content: encodedChart(spec), attachmentsData: nil)
    }

    private static func imageSeed(payload: WorkspaceImagePayload, imageData: Data?) -> WorkspaceBlockSeed {
        WorkspaceBlockSeed(kind: .image, content: encodedImagePayload(payload), attachmentsData: imageData)
    }

    private static func encodedString<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value), let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private static func decode<T: Decodable>(_ type: T.Type, from content: String) -> T? {
        guard let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

@MainActor
final class WorkspaceRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchWorkspaces() throws -> [WorkspaceRecord] {
        var descriptor = FetchDescriptor<WorkspaceRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.blocks]
        return try context.fetch(descriptor)
    }

    func createWorkspace(
        title: String,
        blocks: [WorkspaceBlockSeed],
        sourceConversationID: UUID? = nil
    ) throws -> WorkspaceRecord {
        let workspace = WorkspaceRecord(
            storedTitle: try MessageEncryption.shared.encryptString(title),
            sourceConversationID: sourceConversationID
        )
        context.insert(workspace)

        for (index, seed) in blocks.enumerated() {
            let block = try makeBlock(from: seed, sortOrder: index, workspace: workspace)
            workspace.blocks.append(block)
            context.insert(block)
        }

        workspace.updatedAt = .now
        try context.save()
        return workspace
    }

    func createBlankWorkspace() throws -> WorkspaceRecord {
        try createWorkspace(title: "Untitled Workspace", blocks: [WorkspaceSeedFactory.defaultSeed(for: .text)])
    }

    func renameWorkspace(_ workspace: WorkspaceRecord, title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        workspace.title = try MessageEncryption.shared.encryptString(trimmed.isEmpty ? "Untitled Workspace" : trimmed)
        touch(workspace)
        try context.save()
    }

    func deleteWorkspace(_ workspace: WorkspaceRecord) throws {
        context.delete(workspace)
        try context.save()
    }

    func addBlock(to workspace: WorkspaceRecord, kind: WorkspaceBlockKind) throws -> WorkspaceBlockRecord {
        let block = try makeBlock(
            from: WorkspaceSeedFactory.defaultSeed(for: kind),
            sortOrder: (workspace.blocks.map(\.sortOrder).max() ?? -1) + 1,
            workspace: workspace
        )
        workspace.blocks.append(block)
        context.insert(block)
        touch(workspace)
        try context.save()
        return block
    }

    func deleteBlock(_ block: WorkspaceBlockRecord) throws {
        if let workspace = block.workspace {
            workspace.blocks.removeAll { $0.id == block.id }
            touch(workspace)
        }
        context.delete(block)
        try context.save()
    }

    func updateTextBlock(_ block: WorkspaceBlockRecord, markdown: String) throws {
        try updateBlock(block, content: markdown)
    }

    func updateTableBlock(_ block: WorkspaceBlockRecord, table: MarkdownTable) throws {
        try updateBlock(block, content: WorkspaceSeedFactory.encodedTable(table))
    }

    func updateChartBlock(_ block: WorkspaceBlockRecord, chartJSON: String) throws {
        try updateBlock(block, content: chartJSON)
    }

    func updateImageBlock(
        _ block: WorkspaceBlockRecord,
        payload: WorkspaceImagePayload,
        imageData: Data? = nil,
        replaceImageData: Bool = false
    ) throws {
        block.content = try MessageEncryption.shared.encryptString(WorkspaceSeedFactory.encodedImagePayload(payload))
        if replaceImageData {
            if let imageData {
                block.attachmentsData = try MessageEncryption.shared.encryptData(imageData)
            } else {
                block.attachmentsData = nil
            }
        }
        if let workspace = block.workspace {
            touch(workspace)
        }
        try context.save()
    }

    @discardableResult
    func applyAIRevision(
        to block: WorkspaceBlockRecord,
        revisedSeed: WorkspaceBlockSeed,
        instruction: String,
        provider: LLMProvider,
        modelIdentifier: String,
        applyMode: WorkspaceRevisionApplyMode
    ) throws -> WorkspaceBlockRecord {
        switch applyMode {
        case .replace:
            try createRevisionSnapshot(
                for: block,
                instruction: instruction,
                provider: provider,
                modelIdentifier: modelIdentifier,
                applyMode: applyMode
            )
            block.content = try MessageEncryption.shared.encryptString(revisedSeed.content)
            block.attachmentsData = try revisedSeed.attachmentsData.map { try MessageEncryption.shared.encryptData($0) }
            if let workspace = block.workspace {
                touch(workspace)
            }
            try context.save()
            return block
        case .duplicate:
            guard let workspace = block.workspace else {
                throw WorkspaceRevisionError.unsupportedBlockKind
            }

            shiftSortOrders(after: block.sortOrder, in: workspace)
            let duplicateBlock = try makeBlock(from: revisedSeed, sortOrder: block.sortOrder + 1, workspace: workspace)
            workspace.blocks.append(duplicateBlock)
            context.insert(duplicateBlock)

            try createRevisionSnapshot(
                for: duplicateBlock,
                content: block.content,
                attachmentsData: block.attachmentsData,
                instruction: instruction,
                provider: provider,
                modelIdentifier: modelIdentifier,
                applyMode: applyMode
            )

            touch(workspace)
            try context.save()
            return duplicateBlock
        }
    }

    func restoreRevision(_ revision: WorkspaceBlockRevisionRecord, to block: WorkspaceBlockRecord) throws {
        try createRevisionSnapshot(
            for: block,
            instruction: "Restore previous version",
            provider: nil,
            modelIdentifier: "",
            applyMode: .replace
        )

        block.content = revision.content
        block.attachmentsData = revision.attachmentsData
        if let workspace = block.workspace {
            touch(workspace)
        }
        try context.save()
    }

    private func updateBlock(_ block: WorkspaceBlockRecord, content: String) throws {
        block.content = try MessageEncryption.shared.encryptString(content)
        if let workspace = block.workspace {
            touch(workspace)
        }
        try context.save()
    }

    private func makeBlock(from seed: WorkspaceBlockSeed, sortOrder: Int, workspace: WorkspaceRecord) throws -> WorkspaceBlockRecord {
        let attachmentsData = try seed.attachmentsData.map { try MessageEncryption.shared.encryptData($0) }
        return WorkspaceBlockRecord(
            kind: seed.kind,
            sortOrder: sortOrder,
            storedContent: try MessageEncryption.shared.encryptString(seed.content),
            attachmentsData: attachmentsData,
            workspace: workspace
        )
    }

    private func createRevisionSnapshot(
        for block: WorkspaceBlockRecord,
        content: String? = nil,
        attachmentsData: Data? = nil,
        instruction: String,
        provider: LLMProvider?,
        modelIdentifier: String,
        applyMode: WorkspaceRevisionApplyMode
    ) throws {
        let revision = WorkspaceBlockRevisionRecord(
            storedInstruction: try MessageEncryption.shared.encryptString(instruction),
            providerRawValue: provider?.rawValue ?? "",
            modelIdentifier: modelIdentifier,
            applyMode: applyMode,
            storedContent: content ?? block.content,
            attachmentsData: attachmentsData ?? block.attachmentsData,
            block: block
        )
        block.revisions.append(revision)
        context.insert(revision)
    }

    private func shiftSortOrders(after sortOrder: Int, in workspace: WorkspaceRecord) {
        for block in workspace.blocks where block.sortOrder > sortOrder {
            block.sortOrder += 1
        }
    }

    private func touch(_ workspace: WorkspaceRecord) {
        workspace.updatedAt = .now
    }
}

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var workspaces: [WorkspaceRecord] = []
    @Published var selectedWorkspace: WorkspaceRecord?
    @Published var errorMessage: String?
    @Published var revisingBlockID: UUID?
    @Published var revisionStatusMessage: String?

    private let appState: AppState
    private let repository: WorkspaceRepository

    init(appState: AppState, repository: WorkspaceRepository) {
        self.appState = appState
        self.repository = repository
    }

    func load() {
        do {
            let selectedID = selectedWorkspace?.id
            workspaces = try repository.fetchWorkspaces()
            if let selectedID {
                selectedWorkspace = workspaces.first(where: { $0.id == selectedID }) ?? workspaces.first
            } else {
                selectedWorkspace = workspaces.first
            }
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func createBlankWorkspace() {
        do {
            let workspace = try repository.createBlankWorkspace()
            workspaces.insert(workspace, at: 0)
            selectedWorkspace = workspace
            objectWillChange.send()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func createWorkspace(from message: MessageRecord, conversationTitle: String?) -> WorkspaceRecord? {
        let attachments = decodedAttachments(for: message)
        let title = WorkspaceSeedFactory.workspaceTitle(for: message.decryptedContent, fallback: conversationTitle)
        let seeds = WorkspaceSeedFactory.seeds(from: message.decryptedContent, attachments: attachments)

        do {
            let workspace = try repository.createWorkspace(
                title: title,
                blocks: seeds,
                sourceConversationID: message.conversation?.id
            )
            workspaces.insert(workspace, at: 0)
            selectedWorkspace = workspace
            objectWillChange.send()
            return workspace
        } catch {
            errorMessage = displayMessage(for: error)
            return nil
        }
    }

    func selectWorkspace(_ workspace: WorkspaceRecord?) {
        selectedWorkspace = workspace
    }

    func renameSelectedWorkspace(_ title: String) {
        guard let selectedWorkspace else { return }
        do {
            objectWillChange.send()
            try repository.renameWorkspace(selectedWorkspace, title: title)
            sortWorkspaces()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func deleteSelectedWorkspace() {
        guard let selectedWorkspace else { return }
        do {
            let deletedID = selectedWorkspace.id
            try repository.deleteWorkspace(selectedWorkspace)
            workspaces.removeAll { $0.id == deletedID }
            self.selectedWorkspace = workspaces.first
            objectWillChange.send()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func addBlock(_ kind: WorkspaceBlockKind) {
        guard let selectedWorkspace else { return }
        do {
            _ = try repository.addBlock(to: selectedWorkspace, kind: kind)
            objectWillChange.send()
            sortWorkspaces()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func deleteBlock(_ block: WorkspaceBlockRecord) {
        do {
            try repository.deleteBlock(block)
            objectWillChange.send()
            sortWorkspaces()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func updateTextBlock(_ block: WorkspaceBlockRecord, markdown: String) {
        update {
            try repository.updateTextBlock(block, markdown: markdown)
        }
    }

    func updateTableBlock(_ block: WorkspaceBlockRecord, table: MarkdownTable) {
        update {
            try repository.updateTableBlock(block, table: table)
        }
    }

    func updateChartBlock(_ block: WorkspaceBlockRecord, chartJSON: String) {
        update {
            try repository.updateChartBlock(block, chartJSON: chartJSON)
        }
    }

    func updateImageBlock(_ block: WorkspaceBlockRecord, payload: WorkspaceImagePayload) {
        update {
            try repository.updateImageBlock(block, payload: payload)
        }
    }

    func importTextFile(into block: WorkspaceBlockRecord, from url: URL) {
        do {
            let text = try readText(from: url)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WorkspaceImportError.invalidTextFile
            }
            update {
                try repository.updateTextBlock(block, markdown: text)
            }
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func importCSVFile(into block: WorkspaceBlockRecord, from url: URL) {
        do {
            let text = try readText(from: url)
            guard let table = CSVTableSupport.table(from: text) else {
                throw WorkspaceImportError.invalidCSV
            }
            update {
                try repository.updateTableBlock(block, table: table)
            }
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func importChartJSONFile(into block: WorkspaceBlockRecord, from url: URL) {
        do {
            let text = try readText(from: url)
            guard let chart = WorkspaceSeedFactory.decodeChart(from: text) else {
                throw WorkspaceImportError.invalidChartJSON
            }
            update {
                try repository.updateChartBlock(block, chartJSON: WorkspaceSeedFactory.encodedChart(chart))
            }
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func importImageFile(into block: WorkspaceBlockRecord, from url: URL) {
        do {
            let imageData = try readData(from: url)
            guard NSImage(data: imageData) != nil else {
                throw WorkspaceImportError.invalidImageFile
            }

            var payload = WorkspaceSeedFactory.decodeImagePayload(from: block.decryptedContent)
            if payload.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payload.caption = url.deletingPathExtension().lastPathComponent
            }
            payload.remoteURLString = nil

            update {
                try repository.updateImageBlock(block, payload: payload, imageData: imageData, replaceImageData: true)
            }
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func canRevise(_ block: WorkspaceBlockRecord) -> Bool {
        block.kind == .text || block.kind == .table || block.kind == .chart
    }

    var revisionProvider: LLMProvider {
        appState.settingsStore.defaultProvider
    }

    var revisionModelIdentifier: String {
        appState.settingsStore.selectedModel(for: revisionProvider)
    }

    var revisionModelDisplayLabel: String {
        "\(revisionProvider.displayName) · \(revisionProvider.normalizedModelIdentifier(revisionModelIdentifier))"
    }

    var canExportSelectedWorkspaceDocument: Bool {
        WorkspaceExportService.hasDocumentExport(in: selectedWorkspace)
    }

    func isRevising(_ block: WorkspaceBlockRecord) -> Bool {
        revisingBlockID == block.id
    }

    func reviseBlock(
        _ block: WorkspaceBlockRecord,
        instruction: String,
        applyMode: WorkspaceRevisionApplyMode
    ) async -> Bool {
        let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstruction.isEmpty else {
            errorMessage = WorkspaceRevisionError.emptyInstruction.errorDescription
            return false
        }

        guard canRevise(block) else {
            errorMessage = WorkspaceRevisionError.unsupportedBlockKind.errorDescription
            return false
        }

        let provider = revisionProvider
        let modelIdentifier = revisionProvider.normalizedModelIdentifier(revisionModelIdentifier)
        let service = appState.serviceFactory.makeService(provider: provider)

        do {
            revisingBlockID = block.id
            revisionStatusMessage = "Preparing revision..."
            let request = try WorkspaceAIRevisionComposer.request(
                for: block,
                instruction: trimmedInstruction,
                provider: provider,
                modelIdentifier: modelIdentifier,
                settingsStore: appState.settingsStore
            )

            var output = ""
            for try await event in service.streamResponse(for: request) {
                switch event {
                case .started:
                    revisionStatusMessage = "Sending to \(provider.displayName)..."
                case .status(let status):
                    revisionStatusMessage = status
                case .token(let token):
                    output.append(token)
                case .finished:
                    revisionStatusMessage = "Applying revision..."
                }
            }

            let revisedSeed = try WorkspaceAIRevisionComposer.revisedSeed(from: output, originalBlock: block)
            let revisedBlock = try repository.applyAIRevision(
                to: block,
                revisedSeed: revisedSeed,
                instruction: trimmedInstruction,
                provider: provider,
                modelIdentifier: modelIdentifier,
                applyMode: applyMode
            )
            selectedWorkspace = revisedBlock.workspace ?? selectedWorkspace
            objectWillChange.send()
            sortWorkspaces()
            revisionStatusMessage = nil
            revisingBlockID = nil
            return true
        } catch {
            revisionStatusMessage = nil
            revisingBlockID = nil
            errorMessage = displayMessage(for: error)
            return false
        }
    }

    func restoreRevision(_ revision: WorkspaceBlockRevisionRecord, to block: WorkspaceBlockRecord) {
        do {
            objectWillChange.send()
            try repository.restoreRevision(revision, to: block)
            sortWorkspaces()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func canExportCSV(_ block: WorkspaceBlockRecord) -> Bool {
        WorkspaceExportService.canExportCSV(block)
    }

    func canExportPNG(_ block: WorkspaceBlockRecord) -> Bool {
        WorkspaceExportService.canExportPNG(block)
    }

    func exportSelectedWorkspaceHTML() async {
        guard let selectedWorkspace else {
            errorMessage = ConversationExportError.noWorkspace.errorDescription
            return
        }

        do {
            let exportedFile = try WorkspaceExportService.exportWorkspaceHTML(selectedWorkspace)
            try save(exportedFile)
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func exportSelectedWorkspacePDF() async {
        guard let selectedWorkspace else {
            errorMessage = ConversationExportError.noWorkspace.errorDescription
            return
        }

        do {
            let exportedFile = try await WorkspaceExportService.exportWorkspacePDF(selectedWorkspace)
            try save(exportedFile)
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func exportSelectedWorkspaceDOCX() async {
        guard let selectedWorkspace else {
            errorMessage = ConversationExportError.noWorkspace.errorDescription
            return
        }

        do {
            let exportedFile = try WorkspaceExportService.exportWorkspaceDOCX(selectedWorkspace)
            try save(exportedFile)
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func exportBlockCSV(_ block: WorkspaceBlockRecord) async {
        do {
            let exportedFile = try WorkspaceExportService.exportTableBlockCSV(block)
            try save(exportedFile)
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func exportBlockXLSX(_ block: WorkspaceBlockRecord) async {
        do {
            let exportedFile = try WorkspaceExportService.exportTableBlockXLSX(block)
            try save(exportedFile)
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func exportBlockPNG(_ block: WorkspaceBlockRecord) async {
        do {
            let exportedFile = try await WorkspaceExportService.exportVisualBlockPNG(block)
            try save(exportedFile)
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    private func update(_ operation: () throws -> Void) {
        do {
            objectWillChange.send()
            try operation()
            sortWorkspaces()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    private func sortWorkspaces() {
        workspaces = workspaces.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func readText(from url: URL) throws -> String {
        let data = try readData(from: url)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .unicode) {
            return text
        }
        if let text = String(data: data, encoding: .utf16) {
            return text
        }
        throw WorkspaceImportError.invalidTextFile
    }

    private func readData(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
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

    private func decodedAttachments(for message: MessageRecord) -> [MessageAttachment] {
        guard let attachmentsData = message.decryptedAttachmentsData,
              let attachments = try? JSONDecoder().decode([MessageAttachment].self, from: attachmentsData) else {
            return []
        }
        return attachments
    }

    private func displayMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        return error.localizedDescription
    }
}
