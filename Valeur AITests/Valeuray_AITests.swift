import Foundation
import SwiftData
import Testing
@testable import Valeur_AI

struct TokenFormattingTests {

    @Test func estimatedTokenCountEmpty() {
        #expect(TokenFormatting.estimatedTokenCount(for: "") == 0)
    }

    @Test func estimatedTokenCountApproximate() {
        let text = String(repeating: "word ", count: 100)
        let count = TokenFormatting.estimatedTokenCount(for: text)
        #expect(count > 0)
        #expect(count < 200)
    }

    @Test func compactCountBelow1000() {
        #expect(TokenFormatting.compactCount(500) == "500")
    }

    @Test func compactCountAbove1000() {
        let result = TokenFormatting.compactCount(1500)
        #expect(result.contains("1") && result.lowercased().contains("k"))
    }

    @Test func percentLabel() {
        let result = TokenFormatting.percentLabel(for: 0.5)
        #expect(result.contains("50") || result.contains("%"))
    }

    @Test func percentLabelHalfReturns50() {
        let result = TokenFormatting.percentLabel(for: 0.5)
        #expect(result.contains("50"))
    }
}

@MainActor
struct SettingsStoreNormalizeFontTests {

    @Test func normalizeFontFamilyNameEmpty() {
        let result = SettingsStore.normalizeFontFamilyName(nil)
        #expect(!result.isEmpty)
    }

    @Test func normalizeFontFamilyNameWhitespace() {
        let result = SettingsStore.normalizeFontFamilyName("   ")
        #expect(!result.isEmpty)
    }

    @Test func normalizeFontFamilyNameSystemFont() {
        let result = SettingsStore.normalizeFontFamilyName(AppTheme.systemFontFamilyName)
        #expect(result == AppTheme.systemFontFamilyName)
    }

    @Test func normalizeFontFamilyNameNexaFont() {
        let result = SettingsStore.normalizeFontFamilyName(AppTheme.nexaFontFamilyName)
        #expect(result == AppTheme.nexaFontFamilyName)
    }
}

struct ServiceErrorTests {

    @Test func missingAPIKeyDescription() {
        let error = ServiceError.missingAPIKey("OpenAI")
        #expect(error.errorDescription?.contains("OpenAI") == true)
        #expect(error.errorDescription?.contains("Settings") == true)
    }

    @Test func httpErrorDescription() {
        let error = ServiceError.httpError(401, "Unauthorized")
        #expect(error.errorDescription?.contains("401") == true)
    }

    @Test func providerMessagePreviewTruncates() {
        let longBody = String(repeating: "x", count: 500)
        let error = ServiceError.httpError(500, longBody)
        let description = error.errorDescription ?? ""
        #expect(description.count < 500)
    }
}

struct LLMProviderTests {

    @Test func normalizedModelIdentifierReturnsDefaultForUnknown() {
        let unknown = "not-a-real-model"
        let result = LLMProvider.openAI.normalizedModelIdentifier(unknown)
        #expect(!result.isEmpty)
    }

    @Test func contextWindowTokensPositive() {
        for provider in LLMProvider.allCases {
            let tokens = provider.contextWindowTokens(for: provider.defaultModel)
            #expect(tokens > 0)
        }
    }

    @Test func allProvidersHavePresets() {
        for provider in LLMProvider.allCases {
            #expect(!provider.presets.isEmpty)
        }
    }

    @Test func capabilityMetadataMatchesCurrentProviderBehavior() {
        let openAICapabilities = LLMProvider.openAI.capabilities(for: LLMProvider.openAI.defaultModel)
        #expect(openAICapabilities.supportsVisionInput)
        #expect(openAICapabilities.supportsDocumentInput)
        #expect(openAICapabilities.supportsWebSearch)
        #expect(openAICapabilities.supportsImageGeneration)
        #expect(openAICapabilities.imageGenerationModelIdentifier == "gpt-image-1")

        let anthropicCapabilities = LLMProvider.anthropic.capabilities(for: LLMProvider.anthropic.defaultModel)
        #expect(anthropicCapabilities.supportsVisionInput)
        #expect(anthropicCapabilities.supportsDocumentInput)
        #expect(anthropicCapabilities.supportsWebSearch == false)
        #expect(anthropicCapabilities.supportsImageGeneration == false)

        let geminiCapabilities = LLMProvider.gemini.capabilities(for: LLMProvider.gemini.defaultModel)
        #expect(geminiCapabilities.supportsVisionInput)
        #expect(geminiCapabilities.supportsWebSearch)
        #expect(geminiCapabilities.supportsImageGeneration == false)

        let openRouterCapabilities = LLMProvider.openRouter.capabilities(for: LLMProvider.openRouter.defaultModel)
        #expect(openRouterCapabilities.supportsVisionInput)
        #expect(openRouterCapabilities.supportsDocumentInput)
        #expect(openRouterCapabilities.supportsWebSearch)
        #expect(openRouterCapabilities.supportsImageGeneration == false)
    }

    @Test func imageGenerationModelResolutionUsesCapabilityMetadata() {
        #expect(LLMProvider.openAI.imageGenerationModel(for: LLMProvider.openAI.defaultModel) == "gpt-image-1")
        #expect(LLMProvider.anthropic.imageGenerationModel(for: LLMProvider.anthropic.defaultModel) == nil)
    }
}

struct ImageGenerationSizeTests {

    @Test func allSizesHaveStableRawValues() {
        #expect(ImageGenerationSize.square.rawValue == "1024x1024")
        #expect(ImageGenerationSize.portrait.rawValue == "1024x1536")
        #expect(ImageGenerationSize.landscape.rawValue == "1536x1024")
    }
}

struct WorkspaceSeedFactoryTests {

    @Test func createsOrderedSeedsFromAttachmentsMarkdownAndCharts() {
        let imageData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6Zz14AAAAASUVORK5CYII=")!
        let attachments = [MessageAttachment(data: imageData, mimeType: "image/png")]
        let seeds = WorkspaceSeedFactory.seeds(from: """
        ## Summary

        Revenue is up this quarter.

        | Metric | Value |
        | --- | ---: |
        | Revenue | 12 |

        ![Architecture](https://example.com/diagram.png)

        ```chart
        {
          "type": "bar",
          "title": "Revenue",
          "xLabel": "Month",
          "yLabel": "Value",
          "data": [
            { "label": "Jan", "value": 12 }
          ]
        }
        ```
        """, attachments: attachments)

        #expect(seeds.map(\.kind) == [.image, .text, .table, .image, .chart])
        #expect(seeds[1].content.contains("Summary"))
        #expect(seeds[1].attachmentsData != nil)
        #expect(WorkspaceSeedFactory.decodeTable(from: seeds[2].content)?.rows == [["Revenue", "12"]])
        #expect(WorkspaceSeedFactory.decodeImagePayload(from: seeds[3].content).remoteURLString == "https://example.com/diagram.png")
        #expect(WorkspaceSeedFactory.decodeChart(from: seeds[4].content)?.title == "Revenue")
    }

    @Test func textStorageFallsBackToLegacyMarkdownWhenRichTextDataIsMissing() {
        let attributed = WorkspaceTextStorage.attributedString(plainText: "# Heading\n\nParagraph", richTextData: nil)

        #expect(attributed.string.contains("Heading"))
        #expect(attributed.string.contains("Paragraph"))
    }

    @Test func workspaceTitleUsesContentPreviewBeforeFallback() {
        #expect(WorkspaceSeedFactory.workspaceTitle(for: "  First line\nSecond line  ", fallback: "Chat") == "First line Second line")
        #expect(WorkspaceSeedFactory.workspaceTitle(for: "   ", fallback: "Strategy") == "Strategy Workspace")
    }
}

@MainActor
struct WorkspaceAIRevisionSupportTests {

    @Test func unwrappedCodeFenceRemovesOuterFence() {
        let unwrapped = WorkspaceAIRevisionParser.unwrappedCodeFence("""
        ```json
        { "value": 1 }
        ```
        """)

        #expect(unwrapped == "{ \"value\": 1 }")
    }

    @Test func jsonObjectStringExtractsJSONFromNarrativeWrapper() {
        let json = WorkspaceAIRevisionParser.jsonObjectString(from: "Here you go:\n```json\n{\"headers\":[\"A\"],\"alignments\":[\"leading\"],\"rows\":[[\"1\"]]}\n```")
        #expect(json == "{\"headers\":[\"A\"],\"alignments\":[\"leading\"],\"rows\":[[\"1\"]]}")
    }

    @Test func revisedSeedParsesTableJSONResponse() throws {
        let block = WorkspaceBlockRecord(
            kind: .table,
            sortOrder: 0,
            storedContent: WorkspaceSeedFactory.encodedTable(
                MarkdownTable(headers: ["Metric"], alignments: [.leading], rows: [["Revenue"]])
            )
        )

        let seed = try WorkspaceAIRevisionComposer.revisedSeed(
            from: """
            ```json
            {
              "headers": ["Metric", "Value"],
              "alignments": ["leading", "trailing"],
              "rows": [["Revenue", "12"]]
            }
            ```
            """,
            originalBlock: block
        )

        #expect(seed.kind == .table)
        #expect(WorkspaceSeedFactory.decodeTable(from: seed.content)?.rows == [["Revenue", "12"]])
    }

    @Test func revisedSeedParsesTextHTMLResponse() throws {
        let block = WorkspaceBlockRecord(
            kind: .text,
            sortOrder: 0,
            storedContent: "Draft"
        )

        let seed = try WorkspaceAIRevisionComposer.revisedSeed(
            from: "<h1>Launch Plan</h1><p>Ship the release this week.</p>",
            originalBlock: block
        )

        let attributed = WorkspaceTextStorage.attributedString(plainText: seed.content, richTextData: seed.attachmentsData)
        #expect(seed.kind == .text)
        #expect(seed.attachmentsData != nil)
        #expect(attributed.string.contains("Launch Plan"))
        #expect(attributed.string.contains("Ship the release this week."))
    }
}

@MainActor
struct WorkspaceExportServiceTests {

    @Test func exportWorkspaceHTMLIncludesBlockContent() throws {
        let workspace = WorkspaceRecord(storedTitle: try MessageEncryption.shared.encryptString("Quarterly Review"))
        let textBlock = WorkspaceBlockRecord(
            kind: .text,
            sortOrder: 0,
            storedContent: try MessageEncryption.shared.encryptString("## Summary\n\nRevenue improved."),
            workspace: workspace
        )
        let tableBlock = WorkspaceBlockRecord(
            kind: .table,
            sortOrder: 1,
            storedContent: try MessageEncryption.shared.encryptString(
                WorkspaceSeedFactory.encodedTable(
                    MarkdownTable(headers: ["Metric", "Value"], alignments: [.leading, .trailing], rows: [["Revenue", "12"]])
                )
            ),
            workspace: workspace
        )
        workspace.blocks = [textBlock, tableBlock]

        let exported = try WorkspaceExportService.exportWorkspaceHTML(workspace)
        let html = String(decoding: exported.data, as: UTF8.self)

        #expect(exported.suggestedFilename == "quarterly-review.html")
        #expect(html.contains("Quarterly Review"))
        #expect(html.contains("Revenue improved."))
        #expect(html.contains("Metric"))
    }

    @Test func exportTableBlockCSVUsesWorkspaceFilenameStem() throws {
        let workspace = WorkspaceRecord(storedTitle: try MessageEncryption.shared.encryptString("Planning Board"))
        let tableBlock = WorkspaceBlockRecord(
            kind: .table,
            sortOrder: 0,
            storedContent: try MessageEncryption.shared.encryptString(
                WorkspaceSeedFactory.encodedTable(
                    MarkdownTable(headers: ["Item", "Owner"], alignments: [.leading, .leading], rows: [["Roadmap", "Cliff"]])
                )
            ),
            workspace: workspace
        )

        let exported = try WorkspaceExportService.exportTableBlockCSV(tableBlock)
        let csv = String(decoding: exported.data, as: UTF8.self)

        #expect(exported.suggestedFilename == "planning-board-table.csv")
        #expect(csv == "Item,Owner\nRoadmap,Cliff")
    }
}

struct SpreadsheetSupportTests {

    @Test func csvParserHandlesQuotesAndEmbeddedNewlines() {
        let rows = CSVTableSupport.parseRows(from: #"""
        Name,Notes
        Alice,"Line one
        Line two"
        Bob,"Says ""hello"""
        """#)

        #expect(rows == [
            ["Name", "Notes"],
            ["Alice", "Line one\nLine two"],
            ["Bob", "Says \"hello\""]
        ])
    }

    @Test func csvTableBuilderUsesFirstRowAsHeaders() {
        let table = CSVTableSupport.table(from: "Metric,Value\nRevenue,12\nUsers,240")
        #expect(table?.headers == ["Metric", "Value"])
        #expect(table?.rows == [["Revenue", "12"], ["Users", "240"]])
    }

    @Test func xlsxBuilderProducesZipPackage() throws {
        let table = MarkdownTable(
            headers: ["Metric", "Value"],
            alignments: [.leading, .trailing],
            rows: [["Revenue", "12"]]
        )

        let data = try OOXMLSpreadsheetBuilder.xlsxData(for: table, sheetName: "Board Review")
        let payload = String(decoding: data, as: UTF8.self)

        #expect(data.starts(with: [0x50, 0x4B]))
        #expect(payload.contains("xl/workbook.xml"))
        #expect(payload.contains("xl/worksheets/sheet1.xml"))
    }
}

@MainActor
struct ConversationRecordTokenTests {

    @Test func persistedTotalTokenCountTreatsMissingValuesAsZero() {
        let conversation = ConversationRecord(storedTitle: "Chat", persistedInputTokenCount: nil, persistedOutputTokenCount: nil)
        #expect(conversation.persistedInputTokenCount == nil)
        #expect(conversation.persistedOutputTokenCount == nil)
        #expect(conversation.persistedTotalTokenCount == 0)
    }

    @Test func persistedTokenCountsDefaultToZeroForNewConversations() {
        let conversation = ConversationRecord(storedTitle: "Chat")
        #expect(conversation.persistedInputTokenCount == 0)
        #expect(conversation.persistedOutputTokenCount == 0)
        #expect(conversation.persistedTotalTokenCount == 0)
    }
}

@MainActor
struct ConversationExportServiceTests {

    @Test func safeFilenameStemNormalizesTitle() {
        let stem = ConversationExportService.safeFilenameStem(for: "  Revenue & Growth: Q1/Q2  ")
        #expect(stem == "revenue-growth-q1-q2")
    }

    @Test func csvStringEscapesCommasQuotesAndNewlines() {
        let table = MarkdownTable(
            headers: ["Name", "Notes"],
            alignments: [.leading, .leading],
            rows: [["Alice", "Says \"hello\", often\nwith extra detail"]]
        )

        let csv = ConversationExportService.csvString(for: table)
        #expect(csv == "Name,Notes\nAlice,\"Says \"\"hello\"\", often\nwith extra detail\"")
    }

    @Test func chartFallbackTableIncludesSeriesWhenPresent() {
        let table = ConversationExportService.chartFallbackTable(
            for: MarkdownChartSpec(
                type: .bar,
                title: "Revenue",
                subtitle: nil,
                xLabel: "Month",
                yLabel: "Revenue",
                data: [
                    MarkdownChartPoint(label: "Jan", value: 12, series: "North"),
                    MarkdownChartPoint(label: "Feb", value: 18, series: "South")
                ]
            )
        )

        #expect(table.headers == ["Series", "Month", "Revenue"])
        #expect(table.rows == [["North", "Jan", "12"], ["South", "Feb", "18"]])
    }
}

struct RemoteImageImportTests {

    @Test func normalizedURLTrimsWhitespaceAndRejectsUnsupportedSchemes() {
        #expect(RemoteImageImport.normalizedURL(from: "  https://example.com/cat.png  ")?.absoluteString == "https://example.com/cat.png")
        #expect(RemoteImageImport.normalizedURL(from: "ftp://example.com/cat.png") == nil)
        #expect(RemoteImageImport.normalizedURL(from: "not a url") == nil)
    }

    @Test func supportedImageMimeTypeRequiresRenderableImageData() {
        let imageData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6Zz14AAAAASUVORK5CYII=")!

        let mimeType = RemoteImageImport.supportedImageMimeType(
            fromResponseMimeType: "image/webp",
            fallbackURL: URL(string: "https://example.com/cat.png")!,
            data: imageData
        )

        #expect(mimeType == "image/webp")
        #expect(RemoteImageImport.supportedImageMimeType(
            fromResponseMimeType: "text/html",
            fallbackURL: URL(string: "https://example.com/cat.png")!,
            data: Data("nope".utf8)
        ) == nil)
    }

    @Test func preferredFilenameExtensionFallsBackToURLPath() {
        let remoteURL = URL(string: "https://example.com/render.heic")!

        #expect(RemoteImageImport.preferredFilenameExtension(for: "image/png", fallbackURL: remoteURL) == "png")
        #expect(RemoteImageImport.preferredFilenameExtension(for: "application/octet-stream", fallbackURL: remoteURL) == "heic")
    }
}

@MainActor
struct MarkdownLayoutBlockTests {

    @Test func parsesHeadingAndParagraph() {
        let blocks = MarkdownLayoutBlock.parse("""
        ### Summary

        This is a **structured** response.
        """)

        #expect(blocks.count == 2)
        #expect(blocks[0].kind == .heading(level: 3, text: "Summary"))
        #expect(blocks[1].kind == .paragraph("This is a **structured** response."))
    }

    @Test func parsesBulletsAndOrderedLists() {
        let blocks = MarkdownLayoutBlock.parse("""
        - First point
        - Second point

        1. Step one
        2. Step two
        """)

        #expect(blocks.count == 2)

        if case .list(let items, let isOrdered) = blocks[0].kind {
            #expect(isOrdered == false)
            #expect(items.map(\.text) == ["First point", "Second point"])
        } else {
            Issue.record("Expected unordered list block")
        }

        if case .list(let items, let isOrdered) = blocks[1].kind {
            #expect(isOrdered == true)
            #expect(items.map(\.ordinal) == [1, 2])
            #expect(items.map(\.text) == ["Step one", "Step two"])
        } else {
            Issue.record("Expected ordered list block")
        }
    }

    @Test func doesNotTreatInlineEmphasisAsList() {
        let blocks = MarkdownLayoutBlock.parse("**Important** opening sentence")

        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .paragraph("**Important** opening sentence"))
    }

    @Test func parsesQuotesAndDividers() {
        let blocks = MarkdownLayoutBlock.parse("""
        > Keep this in mind.
        > It matters.

        ---
        """)

        #expect(blocks.count == 2)
        #expect(blocks[0].kind == .quote("Keep this in mind.\nIt matters."))
        #expect(blocks[1].kind == .divider)
    }

    @Test func parsesRemoteMarkdownImage() {
        let blocks = MarkdownLayoutBlock.parse("![Architecture](https://example.com/diagram.png)")

        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .remoteImage(MarkdownRemoteImage(
            altText: "Architecture",
            url: URL(string: "https://example.com/diagram.png")!
        )))
    }

    @Test func parsesMarkdownTable() {
        let blocks = MarkdownLayoutBlock.parse("""
        | Metric | Jan | Feb |
        | :--- | ---: | ---: |
        | Revenue | 12 | 18 |
        | Users | 200 | 260 |
        """)

        #expect(blocks.count == 1)

        if case .table(let table) = blocks[0].kind {
            #expect(table.headers == ["Metric", "Jan", "Feb"])
            #expect(table.alignments == [.leading, .trailing, .trailing])
            #expect(table.rows == [["Revenue", "12", "18"], ["Users", "200", "260"]])
        } else {
            Issue.record("Expected markdown table block")
        }
    }
}

@MainActor
struct MarkdownBlockArtifactTests {

    @Test func parsesChartFenceIntoStructuredChartBlock() {
        let blocks = MarkdownBlock.parse("""
        ```chart
        {
          "type": "bar",
          "title": "Monthly Revenue",
          "xLabel": "Month",
          "yLabel": "Revenue",
          "data": [
            { "label": "Jan", "value": 12 },
            { "label": "Feb", "value": 18 }
          ]
        }
        ```
        """)

        #expect(blocks.count == 1)

        switch blocks[0].kind {
        case .chart(let spec):
            #expect(spec.type == .bar)
            #expect(spec.title == "Monthly Revenue")
            #expect(spec.xLabel == "Month")
            #expect(spec.yLabel == "Revenue")
            #expect(spec.data == [
                MarkdownChartPoint(label: "Jan", value: 12, series: nil),
                MarkdownChartPoint(label: "Feb", value: 18, series: nil)
            ])
        default:
            Issue.record("Expected structured chart block")
        }
    }

    @Test func invalidChartFenceFallsBackToCodeBlock() {
        let blocks = MarkdownBlock.parse("""
        ```chart
        not valid json
        ```
        """)

        #expect(blocks.count == 1)

        switch blocks[0].kind {
        case .code(let language, let code):
            #expect(language == "chart")
            #expect(code.contains("not valid json"))
        default:
            Issue.record("Expected chart fence to fall back to code block")
        }
    }
}

@MainActor
struct ConversationListMetadataTests {

    @Test func metadataUsesTrimmedTitleLatestSummaryAndSearchableText() throws {
        let conversation = ConversationRecord(
            storedTitle: try MessageEncryption.shared.encryptString("  Product Roadmap  ")
        )
        let user = MessageRecord(
            role: .user,
            storedContent: try MessageEncryption.shared.encryptString("Outline the launch plan"),
            conversation: conversation
        )
        let assistant = MessageRecord(
            role: .assistant,
            storedContent: try MessageEncryption.shared.encryptString("\nNext steps and owners\n"),
            conversation: conversation
        )
        conversation.messages = [user, assistant]

        let metadata = ConversationListMetadata.make(for: conversation)

        #expect(metadata.title == "Product Roadmap")
        #expect(metadata.summary == "Next steps and owners")
        #expect(metadata.searchableText.contains("product roadmap"))
        #expect(metadata.searchableText.contains("outline the launch plan"))
    }

    @Test func metadataFallsBackWhenConversationIsEmpty() throws {
        let conversation = ConversationRecord(
            storedTitle: try MessageEncryption.shared.encryptString("   ")
        )

        let metadata = ConversationListMetadata.make(for: conversation)

        #expect(metadata.title == "New Chat")
        #expect(metadata.summary == "No messages yet")
    }
}

struct SecureFileAccessTests {

    @Test func readsPlainTextFileAsynchronously() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("notes.txt")
        try Data("Quarterly planning".utf8).write(to: url, options: .atomic)

        let text = try await SecureFileAccess.text(from: url)

        #expect(text == "Quarterly planning")
    }

    @Test func settingsStoreImportsMemoryDocumentAsynchronously() async throws {
        let defaultsSuite = "SettingsStoreImportsMemoryDocumentAsynchronously"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let url = directory.appendingPathComponent("memory.txt")
        try Data("Customer prefers concise weekly updates".utf8).write(to: url, options: .atomic)

        let settings = await MainActor.run {
            guard let defaults = UserDefaults(suiteName: defaultsSuite) else {
                Issue.record("Could not create isolated defaults suite")
                return SettingsStore(keychain: KeychainService())
            }
            defaults.removePersistentDomain(forName: defaultsSuite)
            return SettingsStore(keychain: KeychainService(), defaults: defaults)
        }

        try await settings.setMemoryDocument(from: url)

        await MainActor.run {
            #expect(settings.hasMemoryDocument)
            #expect(settings.memoryDocumentSummary?.contains("memory.txt") == true)
            UserDefaults(suiteName: defaultsSuite)?.removePersistentDomain(forName: defaultsSuite)
        }
    }
}

@MainActor
struct AppStatePersistenceWarningTests {

    @Test func initializerKeepsPersistenceWarningMessage() {
        let settings = SettingsStore(keychain: KeychainService(), defaults: UserDefaults(suiteName: "AppStatePersistenceWarningTests")!)
        let state = AppState(
            settingsStore: settings,
            serviceFactory: LLMServiceFactory(settingsStore: settings),
            persistenceWarningMessage: "Running in memory only"
        )

        #expect(state.persistenceWarningMessage == "Running in memory only")
    }
}

@MainActor
struct ConversationRepositoryIntegrationTests {

    @Test func appendUpdateRetitleAndDeleteConversationPersistsExpectedState() throws {
        let repository = try makeRepository()
        let conversation = try repository.createConversation(provider: .openAI)

        #expect(conversation.decryptedTitle == "New Chat")

        let userMessage = try repository.appendMessage(
            role: .user,
            content: "Plan the launch checklist for next week.",
            to: conversation
        )
        let assistantMessage = try repository.appendMessage(
            role: .assistant,
            content: "I will draft a checklist and timeline.",
            to: conversation
        )

        try repository.updateMessage(assistantMessage, content: "Checklist ready for review.")
        try repository.retitleConversationIfNeeded(conversation)

        let conversations = try repository.fetchConversations()

        #expect(conversations.count == 1)
        #expect(conversations[0].messages.count == 2)
        #expect(conversations[0].decryptedTitle == "Plan the launch checklist for next week.")
        #expect(conversations[0].persistedInputTokenCount ?? 0 > 0)
        #expect(conversations[0].persistedOutputTokenCount ?? 0 > 0)

        try repository.deleteMessage(userMessage)
        #expect(conversation.messages.count == 1)

        try repository.deleteConversation(conversation)
        #expect(try repository.fetchConversations().isEmpty)
    }

    @Test func fetchConversationsMigratesLegacyPlaintextFields() throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        let conversation = ConversationRecord(
            storedTitle: "Legacy Chat",
            provider: .anthropic,
            storedSystemPromptOverride: "Legacy system prompt"
        )
        let message = MessageRecord(
            role: .user,
            storedContent: "Legacy plaintext body",
            conversation: conversation
        )
        conversation.messages = [message]
        context.insert(conversation)
        context.insert(message)
        try context.save()

        let repository = ConversationRepository(context: context)
        let conversations = try repository.fetchConversations()

        #expect(conversations.count == 1)
        #expect(conversations[0].decryptedTitle == "Legacy Chat")
        #expect(conversations[0].resolvedSystemPrompt == "Legacy system prompt")
        #expect(conversations[0].messages.first?.decryptedContent == "Legacy plaintext body")
        #expect(MessageEncryption.shared.isEncryptedString(conversations[0].title))
        #expect(MessageEncryption.shared.isEncryptedString(conversations[0].systemPromptOverride))
        #expect(MessageEncryption.shared.isEncryptedString(conversations[0].messages[0].content))
    }

    private func makeRepository() throws -> ConversationRepository {
        let container = try Self.makeContainer()
        return ConversationRepository(context: ModelContext(container))
    }

    private static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ConversationRecord.self,
            MessageRecord.self,
            WorkspaceRecord.self,
            WorkspaceBlockRecord.self,
            WorkspaceBlockRevisionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

@MainActor
struct ProviderServiceIntegrationTests {

    @Test func streamResponseRejectsMissingAPIKeysBeforeNetworkAccess() async {
        let request = ChatRequest(
            messages: [ChatMessagePayload(role: .user, content: "Hello")],
            systemPrompt: nil,
            model: "gpt-5.4-mini",
            allowsWebSearch: false
        )

        await assertMissingAPIKey(
            from: OpenAIService(apiKey: "").streamResponse(for: request),
            providerName: "OpenAI"
        )
        await assertMissingAPIKey(
            from: AnthropicService(apiKey: "").streamResponse(for: request),
            providerName: "Anthropic"
        )
        await assertMissingAPIKey(
            from: GeminiService(apiKey: "").streamResponse(for: request),
            providerName: "Google Gemini"
        )
        await assertMissingAPIKey(
            from: OpenRouterService(apiKey: "").streamResponse(for: request),
            providerName: "OpenRouter"
        )
    }

    @Test func imageGenerationRejectsMissingOpenAIAPIKeyBeforeNetworkAccess() async throws {
        do {
            _ = try await OpenAIService(apiKey: "").generateImage(
                for: ImageGenerationRequest(
                    prompt: "Generate a product concept render",
                    model: "gpt-image-1",
                    size: .square
                )
            )
            Issue.record("Expected generateImage to fail when API key is missing")
        } catch let error as ServiceError {
            switch error {
            case .missingAPIKey(let providerName):
                #expect(providerName == "OpenAI")
            default:
                Issue.record("Expected missingAPIKey error, got \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Expected ServiceError, got \(error.localizedDescription)")
        }
    }

    private func assertMissingAPIKey(
        from stream: AsyncThrowingStream<LLMStreamEvent, Error>,
        providerName: String
    ) async {
        do {
            for try await _ in stream {
            }
            Issue.record("Expected stream to fail for \(providerName)")
        } catch let error as ServiceError {
            switch error {
            case .missingAPIKey(let resolvedProviderName):
                #expect(resolvedProviderName == providerName)
            default:
                Issue.record("Expected missingAPIKey for \(providerName), got \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Expected ServiceError for \(providerName), got \(error.localizedDescription)")
        }
    }
}

struct ProviderStreamParserFixtureTests {

    @Test func openAIParsesTokenStatusAndRecoveredOutputFixtures() throws {
        let tokenEvents = try ProviderStreamParserTestHarness.parseOpenAIEvent(#"{"type":"response.output_text.delta","delta":"Hello"}"#)
        let statusEvents = try ProviderStreamParserTestHarness.parseOpenAIEvent(#"{"type":"response.step.created"}"#)
        let recoveredEvents = try ProviderStreamParserTestHarness.recoverOpenAINonStreamingBody(#"{"output":[{"role":"assistant","content":[{"type":"output_text","text":"Recovered answer"}]}]}"#)

        #expect(eventDescriptions(tokenEvents) == ["token:Hello"])
        #expect(eventDescriptions(statusEvents) == ["status:Searching the web..."])
        #expect(eventDescriptions(recoveredEvents) == ["token:Recovered answer"])
    }

    @Test func openAIFixtureSurfacesProviderErrorMessage() throws {
        do {
            _ = try ProviderStreamParserTestHarness.parseOpenAIEvent(#"{"type":"response.completed","response":{"error":{"message":"rate limited","code":"429"}}}"#)
            Issue.record("Expected provider message error")
        } catch let error as ServiceError {
            switch error {
            case .providerMessage(let message):
                #expect(message.contains("rate limited"))
                #expect(message.contains("429"))
            default:
                Issue.record("Expected providerMessage, got \(error.localizedDescription)")
            }
        }
    }

    @Test func anthropicParsesTokenStatusAndFinishedFixtures() throws {
        let tokenEvents = try ProviderStreamParserTestHarness.parseAnthropicEvent(
            name: "content_block_delta",
            data: #"{"delta":{"text":"Thinking through it"}}"#
        )
        let statusEvents = try ProviderStreamParserTestHarness.parseAnthropicEvent(
            name: "content_block_start",
            data: #"{"content_block":{"type":"tool_use"}}"#
        )
        let finishedEvents = try ProviderStreamParserTestHarness.parseAnthropicEvent(
            name: "message_stop",
            data: "{}"
        )

        #expect(eventDescriptions(tokenEvents) == ["token:Thinking through it"])
        #expect(eventDescriptions(statusEvents) == ["status:Using tool..."])
        #expect(eventDescriptions(finishedEvents) == ["finished"])
    }

    @Test func geminiParsesTokenAndRecoveredProviderErrorFixtures() throws {
        let tokenEvents = try ProviderStreamParserTestHarness.parseGeminiEvent(#"{"candidates":[{"content":{"parts":[{"text":"Part one"},{"text":" and two"}]}}]}"#)

        #expect(eventDescriptions(tokenEvents) == ["token:Part one", "token: and two"])

        do {
            _ = try ProviderStreamParserTestHarness.recoverGeminiNonStreamingBody(#"{"error":{"message":"quota exceeded"}}"#)
            Issue.record("Expected Gemini provider error")
        } catch let error as ServiceError {
            switch error {
            case .providerMessage(let message):
                #expect(message.contains("quota exceeded"))
            default:
                Issue.record("Expected providerMessage, got \(error.localizedDescription)")
            }
        }
    }

    @Test func openRouterParsesStreamingAndRecoveredFixtures() throws {
        let tokenEvents = try ProviderStreamParserTestHarness.parseOpenRouterEvent(#"{"choices":[{"delta":{"content":"Hello from OpenRouter"}}]}"#)
        let recoveredEvents = try ProviderStreamParserTestHarness.recoverOpenRouterNonStreamingBody(#"{"choices":[{"message":{"role":"assistant","content":"Recovered OpenRouter answer"}}]}"#)

        #expect(eventDescriptions(tokenEvents) == ["token:Hello from OpenRouter"])
        #expect(eventDescriptions(recoveredEvents) == ["token:Recovered OpenRouter answer"])
    }

    private func eventDescriptions(_ events: [LLMStreamEvent]) -> [String] {
        events.map { event in
            switch event {
            case .started:
                return "started"
            case .token(let token):
                return "token:\(token)"
            case .status(let status):
                return "status:\(status)"
            case .finished:
                return "finished"
            }
        }
    }
}

struct ProviderRequestBodyFixtureTests {

    @Test func openAIRequestBodyIncludesInstructionsToolsAndImageParts() throws {
        let imageData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6Zz14AAAAASUVORK5CYII=")!
        let request = ChatRequest(
            messages: [
                ChatMessagePayload(
                    role: .user,
                    content: "Inspect this image",
                    attachments: [MessageAttachment(data: imageData, mimeType: "image/png")]
                )
            ],
            systemPrompt: "Be precise",
            model: "gpt-5.4-mini",
            allowsWebSearch: true
        )

        let json = try ProviderStreamParserTestHarness.openAIRequestBody(for: request)

        #expect(json["model"] as? String == "gpt-5.4-mini")
        #expect(json["instructions"] as? String == "Be precise")
        #expect((json["tools"] as? [[String: Any]])?.first?["type"] as? String == "web_search")

        let input = try #require(json["input"] as? [[String: Any]])
        let content = try #require(input.first?["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "input_text")
        #expect(content.last?["type"] as? String == "input_image")
    }

    @Test func anthropicRequestBodyIncludesSystemAndDocumentParts() throws {
        let pdfData = Data("pdf".utf8)
        let request = ChatRequest(
            messages: [
                ChatMessagePayload(
                    role: .user,
                    content: "Summarize the document",
                    attachments: [MessageAttachment(data: pdfData, mimeType: "application/pdf")]
                )
            ],
            systemPrompt: "Answer briefly",
            model: "claude-sonnet-4-6",
            allowsWebSearch: false
        )

        let json = try ProviderStreamParserTestHarness.anthropicRequestBody(for: request)

        #expect(json["model"] as? String == "claude-sonnet-4-6")
        #expect(json["system"] as? String == "Answer briefly")
        let messages = try #require(json["messages"] as? [[String: Any]])
        let parts = try #require(messages.first?["content"] as? [[String: Any]])
        #expect(parts.first?["type"] as? String == "document")
        #expect(parts.last?["type"] as? String == "text")
    }

    @Test func geminiRequestBodyIncludesSystemSearchAndInlineData() throws {
        let imageData = Data("image".utf8)
        let request = ChatRequest(
            messages: [
                ChatMessagePayload(
                    role: .user,
                    content: "Analyze this",
                    attachments: [MessageAttachment(data: imageData, mimeType: "image/png")]
                )
            ],
            systemPrompt: "Use concise bullet points",
            model: "gemini-2.5-flash",
            allowsWebSearch: true
        )

        let json = try ProviderStreamParserTestHarness.geminiRequestBody(for: request)

        let systemInstruction = try #require(json["systemInstruction"] as? [String: Any])
        let instructionParts = try #require(systemInstruction["parts"] as? [[String: Any]])
        #expect(instructionParts.first?["text"] as? String == "Use concise bullet points")
        #expect((json["tools"] as? [[String: Any]])?.first?["googleSearch"] as? [String: Any] != nil)

        let contents = try #require(json["contents"] as? [[String: Any]])
        let parts = try #require(contents.first?["parts"] as? [[String: Any]])
        let inlineData = try #require(parts.last?["inlineData"] as? [String: Any])
        #expect(inlineData["mimeType"] as? String == "image/png")
    }

    @Test func openRouterRequestBodyIncludesPluginsSystemAndFileParts() throws {
        let pdfData = Data("pdf".utf8)
        let request = ChatRequest(
            messages: [
                ChatMessagePayload(
                    role: .user,
                    content: "Summarize this PDF",
                    attachments: [MessageAttachment(data: pdfData, mimeType: "application/pdf")]
                )
            ],
            systemPrompt: "Answer with bullet points",
            model: "anthropic/claude-sonnet-4",
            allowsWebSearch: true
        )

        let json = try ProviderStreamParserTestHarness.openRouterRequestBody(for: request)

        #expect(json["model"] as? String == "anthropic/claude-sonnet-4")
        let plugins = try #require(json["plugins"] as? [[String: Any]])
        #expect(plugins.contains(where: { $0["id"] as? String == "web" }))
        #expect(plugins.contains(where: { $0["id"] as? String == "file-parser" }))

        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.first?["role"] as? String == "system")
        #expect(messages.first?["content"] as? String == "Answer with bullet points")

        let content = try #require(messages.last?["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "text")
        #expect(content.last?["type"] as? String == "file")
    }
}

struct SSEParserByteStreamTests {

    @Test func parsesMultiLineAndFragmentedEventsFromBytes() async throws {
        let events = try await parseEvents(from: "event: update\ndata: first line\ndata: second line\n\ndata: final\n\n")

        #expect(events.count == 2)

        if case .message(let name, let data) = events[0] {
            #expect(name == "update")
            #expect(data == "first line\nsecond line")
        } else {
            Issue.record("Expected first SSE event")
        }

        if case .message(let name, let data) = events[1] {
            #expect(name == nil)
            #expect(data == "final")
        } else {
            Issue.record("Expected second SSE event")
        }
    }

    @Test func parsesCRLFAndTrailingEventWithoutFinalBlankLine() async throws {
        let events = try await parseEvents(from: "event: status\r\ndata: working\r\n\r\ndata: trailing")

        #expect(events.count == 2)
        if case .message(let name, let data) = events[0] {
            #expect(name == "status")
            #expect(data == "working")
        }
        if case .message(let name, let data) = events[1] {
            #expect(name == nil)
            #expect(data == "trailing")
        }
    }

    @Test func rejectsTooManyBufferedLines() async {
        let payload = Array(repeating: "data: x", count: 1_001).joined(separator: "\n") + "\n"

        do {
            _ = try await parseEvents(from: payload)
            Issue.record("Expected tooManyBufferedLines error")
        } catch let error as SSEParserError {
            #expect(error == .tooManyBufferedLines)
        } catch {
            Issue.record("Expected SSEParserError, got \(error.localizedDescription)")
        }
    }

    private func parseEvents(from text: String) async throws -> [SSEEvent] {
        let stream = AsyncStream<UInt8> { continuation in
            for byte in text.utf8 {
                continuation.yield(byte)
            }
            continuation.finish()
        }

        var events: [SSEEvent] = []
        for try await event in SSEParser.events(from: stream) {
            events.append(event)
        }
        return events
    }
}
