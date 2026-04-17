import Foundation

protocol LLMService {
    var provider: LLMProvider { get }
    func streamResponse(for request: ChatRequest) -> AsyncThrowingStream<LLMStreamEvent, Error>
}

enum ServiceError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse
    case httpError(Int, String)
    case providerMessage(String)
    case malformedStream(String, String)
    case unsupportedPayload

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider). Add it in Settings."
        case .invalidResponse:
            return "The service returned an invalid response."
        case .httpError(let code, let body):
            return "API error \(code): \(Self.preview(body))"
        case .providerMessage(let message):
            return Self.preview(message)
        case .malformedStream(let provider, let payloadPreview):
            _ = payloadPreview
            return "\(provider) returned data in an unexpected format."
        case .unsupportedPayload:
            return "Unsupported streaming payload."
        }
    }

    private static func preview(_ value: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shortened = String(collapsed.prefix(220))
        return shortened.isEmpty ? "No additional details were returned." : shortened
    }
}

struct LLMServiceFactory {
    let settingsStore: SettingsStore

    @MainActor
    func makeService(provider: LLMProvider) -> LLMService {
        switch provider {
        case .openAI:
            OpenAIService(apiKey: settingsStore.apiKey(for: .openAI))
        case .anthropic:
            AnthropicService(apiKey: settingsStore.apiKey(for: .anthropic))
        case .gemini:
            GeminiService(apiKey: settingsStore.apiKey(for: .gemini))
        }
    }
}
