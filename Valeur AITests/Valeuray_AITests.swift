import Foundation
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
