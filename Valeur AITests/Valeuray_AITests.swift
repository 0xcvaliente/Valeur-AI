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
}
