import Foundation
import OSLog

private let streamLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.sehford.valeurayai.macosapp",
    category: "LLMStream"
)

struct OpenAIService: LLMService {
    let provider: LLMProvider = .openAI
    let apiKey: String

    func streamResponse(for request: ChatRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        do {
            return streamRequest(
                provider: provider,
                endpoint: URL(string: "https://api.openai.com/v1/responses")!,
                method: "POST",
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json"
                ],
                body: try openAIBody(for: request)
            ) { event in
                try parseOpenAIEvent(event)
            }
        } catch {
            return failedStream(error)
        }
    }

    func generateImage(for request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let json = try await jsonRequest(
            provider: provider,
            endpoint: URL(string: "https://api.openai.com/v1/images/generations")!,
            method: "POST",
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ],
            body: try openAIImageBody(for: request)
        )
        return try await parseOpenAIImageResponse(from: json)
    }

    fileprivate func openAIBody(for request: ChatRequest) throws -> Data {
        var body: [String: Any] = [
            "model": request.model,
            "stream": true,
            "input": openAIInput(from: request)
        ]
        if request.allowsWebSearch {
            body["tools"] = [["type": "web_search"]]
        }
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            body["instructions"] = systemPrompt
        }
        return try jsonBody(body, provider: provider)
    }

    private func openAIInput(from request: ChatRequest) -> [[String: Any]] {
        request.messages.map { message in
            var content: Any = message.content
            if let attachments = message.attachments, !attachments.isEmpty {
                var parts: [[String: Any]] = []
                if !message.content.isEmpty {
                    parts.append(["type": "input_text", "text": message.content])
                }
                for attachment in attachments {
                    let b64 = attachment.data.base64EncodedString()
                    if attachment.mimeType == "application/pdf" {
                        parts.append([
                            "type": "file",
                            "file": [
                                "file_data": "data:application/pdf;base64,\(b64)",
                                "filename": "document.pdf"
                            ]
                        ])
                    } else {
                        parts.append([
                            "type": "input_image",
                            "image_url": "data:\(attachment.mimeType);base64,\(b64)"
                        ])
                    }
                }
                content = parts
            }
            return [
                "type": "message",
                "role": message.role.rawValue,
                "content": content
            ]
        }
    }

    private func openAIImageBody(for request: ImageGenerationRequest) throws -> Data {
        try jsonBody([
            "model": request.model,
            "prompt": request.prompt,
            "size": request.size.rawValue,
            "response_format": "b64_json"
        ], provider: provider)
    }

    fileprivate func parseOpenAIEvent(_ event: SSEEvent) throws -> [LLMStreamEvent] {
        guard case .message(_, let data) = event else { return [] }
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        if trimmed == "[DONE]" { return [.finished] }

        let json = try streamJSONObject(from: trimmed, provider: provider)

        if let type = json["type"] as? String {
            switch type {
            case "response.output_text.delta":
                guard let delta = json["delta"] as? String, !delta.isEmpty else {
                    return []
                }
                return [.token(delta)]
            case "response.function_call.arguments.delta", "response.step.created":
                return [.status("Searching the web...")]
            case "response.completed":
                if let response = json["response"] as? [String: Any],
                   let providerMessage = extractProviderMessage(from: response) {
                    throw ServiceError.providerMessage(providerMessage)
                }
                return [.finished]
            default:
                return []
            }
        }

        return recoverOpenAIOutput(from: json)
    }

    private func recoverOpenAIOutput(from json: [String: Any]) -> [LLMStreamEvent] {
        guard let output = json["output"] as? [[String: Any]] else {
            return []
        }

        let text = output
            .filter { ($0["role"] as? String) == Role.assistant.rawValue }
            .flatMap { message -> [String] in
                guard let content = message["content"] as? [[String: Any]] else {
                    return []
                }
                return content.compactMap { item in
                    guard (item["type"] as? String) == "output_text" else {
                        return nil
                    }
                    return item["text"] as? String
                }
            }
            .joined()

        guard !text.isEmpty else {
            return []
        }

        return [.token(text)]
    }

    private func parseOpenAIImageResponse(from json: [String: Any]) async throws -> ImageGenerationResponse {
        guard let items = json["data"] as? [[String: Any]], !items.isEmpty else {
            throw ServiceError.invalidResponse
        }

        var attachments: [MessageAttachment] = []
        var revisedPrompt: String?

        for item in items {
            if revisedPrompt == nil {
                revisedPrompt = item["revised_prompt"] as? String
            }

            if let base64 = item["b64_json"] as? String,
               let data = Data(base64Encoded: base64), !data.isEmpty {
                attachments.append(MessageAttachment(data: data, mimeType: "image/png"))
                continue
            }

            if let urlString = item["url"] as? String,
               let url = URL(string: urlString) {
                attachments.append(try await downloadImageAttachment(from: url))
            }
        }

        guard !attachments.isEmpty else {
            throw ServiceError.invalidResponse
        }

        return ImageGenerationResponse(images: attachments, revisedPrompt: revisedPrompt)
    }
}

struct AnthropicService: LLMService {
    let provider: LLMProvider = .anthropic
    let apiKey: String

    func streamResponse(for request: ChatRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        do {
            return streamRequest(
                provider: provider,
                endpoint: URL(string: "https://api.anthropic.com/v1/messages")!,
                method: "POST",
                headers: [
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json"
                ],
                body: try anthropicBody(for: request)
            ) { event in
                try parseAnthropicEvent(event)
            }
        } catch {
            return failedStream(error)
        }
    }

    fileprivate func anthropicBody(for request: ChatRequest) throws -> Data {
        let messages = request.messages.map { message -> [String: Any] in
            var content: Any = message.content
            if let attachments = message.attachments, !attachments.isEmpty {
                var parts: [[String: Any]] = []
                for attachment in attachments {
                    let b64 = attachment.data.base64EncodedString()
                    if attachment.mimeType == "application/pdf" {
                        parts.append([
                            "type": "document",
                            "source": [
                                "type": "base64",
                                "media_type": attachment.mimeType,
                                "data": b64
                            ]
                        ])
                    } else {
                        parts.append([
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": attachment.mimeType,
                                "data": b64
                            ]
                        ])
                    }
                }
                if !message.content.isEmpty {
                    parts.append(["type": "text", "text": message.content])
                }
                content = parts
            }
            return ["role": message.role.rawValue, "content": content]
        }
        var body: [String: Any] = [
            "model": request.model,
            "stream": true,
            "max_tokens": 4096,
            "messages": messages
        ]
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }
        return try jsonBody(body, provider: provider)
    }

    fileprivate func parseAnthropicEvent(_ event: SSEEvent) throws -> [LLMStreamEvent] {
        guard case .message(let name, let data) = event else { return [] }
        if name == "message_stop" { return [.finished] }
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        let json = try streamJSONObject(from: trimmed, provider: provider)

        if name == "content_block_delta",
           let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return [.token(text)]
        }
        
        if name == "content_block_start" {
           if let block = json["content_block"] as? [String: Any], let type = block["type"] as? String {
               if type == "thinking" {
                   return [.status("Thinking...")]
               } else if type == "tool_use" {
                   return [.status("Using tool...")]
               }
           }
        }

        return []
    }
}

struct GeminiService: LLMService {
    let provider: LLMProvider = .gemini
    let apiKey: String

    func streamResponse(for request: ChatRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        do {
            let encodedModel = request.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.model
            var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):streamGenerateContent")!
            components.queryItems = [URLQueryItem(name: "alt", value: "sse")]
            guard let url = components.url else {
                return failedStream(ServiceError.providerMessage("Invalid Gemini endpoint URL."))
            }
            return streamRequest(
                provider: provider,
                endpoint: url,
                method: "POST",
                headers: [
                    "Content-Type": "application/json",
                    "X-Goog-Api-Key": apiKey
                ],
                body: try geminiBody(for: request)
            ) { event in
                try parseGeminiEvent(event)
            }
        } catch {
            return failedStream(error)
        }
    }

    fileprivate func geminiBody(for request: ChatRequest) throws -> Data {
        let contents = request.messages.map { message -> [String: Any] in
            var parts: [[String: Any]] = []
            if !message.content.isEmpty {
                parts.append(["text": message.content])
            }
            if let attachments = message.attachments {
                for attachment in attachments {
                    let b64 = attachment.data.base64EncodedString()
                    parts.append([
                        "inlineData": [
                            "mimeType": attachment.mimeType,
                            "data": b64
                        ]
                    ])
                }
            }
            if parts.isEmpty {
                parts.append(["text": ""])
            }
            return [
                "role": message.role == .assistant ? "model" : "user",
                "parts": parts
            ]
        }

        var body: [String: Any] = [
            "contents": contents
        ]
        if request.allowsWebSearch {
            body["tools"] = [
                ["googleSearch": [String: Any]()]
            ]
        }
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }
        return try jsonBody(body, provider: provider)
    }

    fileprivate func parseGeminiEvent(_ event: SSEEvent) throws -> [LLMStreamEvent] {
        guard case .message(_, let data) = event else { return [] }
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        let json = try streamJSONObject(from: trimmed, provider: provider)
        guard
            let candidates = json["candidates"] as? [[String: Any]]
        else {
            return []
        }

        var events: [LLMStreamEvent] = []
        for candidate in candidates {
            guard
                let content = candidate["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else {
                continue
            }

            for part in parts {
                if let text = part["text"] as? String, !text.isEmpty {
                    events.append(.token(text))
                }
            }
        }
        return events
    }
}

enum ProviderStreamParserTestHarness {
    private static func decodeJSONBody(_ data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.invalidResponse
        }
        return json
    }

    static func parseOpenAIEvent(_ data: String) throws -> [LLMStreamEvent] {
        try OpenAIService(apiKey: "test-key").parseOpenAIEvent(.message(event: nil, data: data))
    }

    static func parseAnthropicEvent(name: String?, data: String) throws -> [LLMStreamEvent] {
        try AnthropicService(apiKey: "test-key").parseAnthropicEvent(.message(event: name, data: data))
    }

    static func parseGeminiEvent(_ data: String) throws -> [LLMStreamEvent] {
        try GeminiService(apiKey: "test-key").parseGeminiEvent(.message(event: nil, data: data))
    }

    static func recoverOpenAINonStreamingBody(_ body: String) throws -> [LLMStreamEvent] {
        try recoverEventsFromNonStreamingBody(
            provider: .openAI,
            responseBody: body,
            parser: { try OpenAIService(apiKey: "test-key").parseOpenAIEvent($0) }
        )
    }

    static func recoverGeminiNonStreamingBody(_ body: String) throws -> [LLMStreamEvent] {
        try recoverEventsFromNonStreamingBody(
            provider: .gemini,
            responseBody: body,
            parser: { try GeminiService(apiKey: "test-key").parseGeminiEvent($0) }
        )
    }

    static func openAIRequestBody(for request: ChatRequest) throws -> [String: Any] {
        try decodeJSONBody(try OpenAIService(apiKey: "test-key").openAIBody(for: request))
    }

    static func anthropicRequestBody(for request: ChatRequest) throws -> [String: Any] {
        try decodeJSONBody(try AnthropicService(apiKey: "test-key").anthropicBody(for: request))
    }

    static func geminiRequestBody(for request: ChatRequest) throws -> [String: Any] {
        try decodeJSONBody(try GeminiService(apiKey: "test-key").geminiBody(for: request))
    }
}

private func streamRequest(
    provider: LLMProvider,
    endpoint: URL,
    method: String,
    headers: [String: String],
    body: Data,
    parser: @escaping (SSEEvent) throws -> [LLMStreamEvent]
) -> AsyncThrowingStream<LLMStreamEvent, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                try validateAuthenticationHeaders(headers)

                var request = URLRequest(url: endpoint)
                request.httpMethod = method
                request.httpBody = body
                request.timeoutInterval = 120
                headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw ServiceError.invalidResponse
                }

                guard 200..<300 ~= http.statusCode else {
                    let responseBody = try await collectBytes(bytes)
                    throw ServiceError.httpError(http.statusCode, responseBody)
                }

                let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
                if !contentType.isEmpty, !contentType.contains("text/event-stream") {
                    let responseBody = try await collectBytes(bytes)
                    let recoveredEvents = try recoverEventsFromNonStreamingBody(
                        provider: provider,
                        responseBody: responseBody,
                        parser: parser
                    )
                    continuation.yield(.started)
                    for item in recoveredEvents {
                        continuation.yield(item)
                    }
                    continuation.yield(.finished)
                    continuation.finish()
                    return
                }

                continuation.yield(.started)
                for try await event in SSEParser.events(from: bytes) {
                    let parsed: [LLMStreamEvent]
                    do {
                        parsed = try parser(event)
                    } catch let error as ServiceError {
                        if shouldSkipMalformedEvent(error, provider: provider) {
                            streamLogger.error(
                                "Skipping malformed \(provider.displayName, privacy: .public) stream chunk (\(eventSummary(for: event), privacy: .public))"
                            )
                            continue
                        }
                        throw error
                    } catch {
                        let wrappedError = ServiceError.malformedStream(provider.displayName, preview(for: event))
                        if shouldSkipMalformedEvent(wrappedError, provider: provider) {
                            streamLogger.error(
                                "Skipping malformed \(provider.displayName, privacy: .public) stream chunk (\(eventSummary(for: event), privacy: .public))"
                            )
                            continue
                        }
                        throw wrappedError
                    }
                    for item in parsed {
                        continuation.yield(item)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}

private func jsonRequest(
    provider: LLMProvider,
    endpoint: URL,
    method: String,
    headers: [String: String],
    body: Data
) async throws -> [String: Any] {
    try validateAuthenticationHeaders(headers)

    var request = URLRequest(url: endpoint)
    request.httpMethod = method
    request.httpBody = body
    request.timeoutInterval = 120
    headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw ServiceError.invalidResponse
    }

    let responseBody = String(decoding: data, as: UTF8.self)
    guard 200..<300 ~= http.statusCode else {
        throw ServiceError.httpError(http.statusCode, responseBody)
    }

    guard !responseBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ServiceError.invalidResponse
    }

    return try streamJSONObject(from: responseBody, provider: provider)
}

private func validateAuthenticationHeaders(_ headers: [String: String]) throws {
    if let apiKey = headers["Authorization"], apiKey.hasSuffix("Bearer ") {
        throw ServiceError.missingAPIKey("OpenAI")
    }
    if let apiKey = headers["x-api-key"], apiKey.isEmpty {
        throw ServiceError.missingAPIKey("Anthropic")
    }
    if let apiKey = headers["X-Goog-Api-Key"], apiKey.isEmpty {
        throw ServiceError.missingAPIKey("Google Gemini")
    }
}

private func downloadImageAttachment(from url: URL) async throws -> MessageAttachment {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
        throw ServiceError.invalidResponse
    }

    let mimeType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased().split(separator: ";").first.map(String.init)
        ?? inferredImageMimeType(from: url)
    return MessageAttachment(data: data, mimeType: mimeType)
}

private func inferredImageMimeType(from url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "jpg", "jpeg":
        return "image/jpeg"
    case "webp":
        return "image/webp"
    case "gif":
        return "image/gif"
    default:
        return "image/png"
    }
}

private func failedStream(_ error: Error) -> AsyncThrowingStream<LLMStreamEvent, Error> {
    AsyncThrowingStream { continuation in
        continuation.finish(throwing: error)
    }
}

private func jsonBody(_ object: Any, provider: LLMProvider) throws -> Data {
    do {
        return try JSONSerialization.data(withJSONObject: object)
    } catch {
        throw ServiceError.providerMessage("Failed to build a valid request for \(provider.displayName).")
    }
}

private func recoverEventsFromNonStreamingBody(
    provider: LLMProvider,
    responseBody: String,
    parser: (SSEEvent) throws -> [LLMStreamEvent]
) throws -> [LLMStreamEvent] {
    if let providerMessage = extractProviderMessage(from: responseBody) {
        throw ServiceError.providerMessage(providerMessage)
    }

    let trimmed = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw ServiceError.invalidResponse
    }

    do {
        let recovered = try parser(.message(event: nil, data: trimmed))
        streamLogger.notice(
            "Recovered \(provider.displayName, privacy: .public) response from non-streaming body"
        )
        return recovered
    } catch let error as ServiceError {
        if shouldSkipMalformedEvent(error, provider: provider) {
            streamLogger.error(
                "Recoverable malformed \(provider.displayName, privacy: .public) non-stream body (\(trimmed.utf8.count, privacy: .public) bytes)"
            )
            return []
        }
        throw error
    } catch {
        throw ServiceError.malformedStream(provider.displayName, trimmed)
    }
}

private func shouldSkipMalformedEvent(_ error: ServiceError, provider: LLMProvider) -> Bool {
    guard provider == .openAI else { return false }

    switch error {
    case .malformedStream, .unsupportedPayload:
        return true
    default:
        return false
    }
}

private func streamJSONObject(from payload: String, provider: LLMProvider) throws -> [String: Any] {
    guard let data = payload.data(using: .utf8) else {
        throw ServiceError.malformedStream(provider.displayName, payload)
    }

    do {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.unsupportedPayload
        }

        if let providerMessage = extractProviderMessage(from: json) {
            throw ServiceError.providerMessage(providerMessage)
        }

        return json
    } catch let error as ServiceError {
        throw error
    } catch {
        throw ServiceError.malformedStream(provider.displayName, payload)
    }
}

private func extractProviderMessage(from responseBody: String) -> String? {
    guard let data = responseBody.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return nil
    }

    return extractProviderMessage(from: json)
}

private func extractProviderMessage(from json: [String: Any]) -> String? {
    if let error = json["error"] as? [String: Any] {
        let message = error["message"] as? String
            ?? error["status"] as? String
            ?? error["type"] as? String
        if let code = error["code"] {
            if let message {
                return "\(message) (code: \(code))"
            }
            return "API error code: \(code)"
        }
        if let message {
            return message
        }
    }

    if let message = json["message"] as? String,
       (json["type"] as? String) == "error" || json["status"] as? String == "error" {
        return message
    }

    return nil
}

private func preview(for event: SSEEvent) -> String {
    switch event {
    case .message(let name, let data):
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return "\(name): \(trimmed)"
        }
        return trimmed
    }
}

private func eventSummary(for event: SSEEvent) -> String {
    switch event {
    case .message(let name, let data):
        let eventName = (name?.isEmpty == false) ? name! : "message"
        return "event=\(eventName) bytes=\(data.utf8.count)"
    }
}

private let maxResponseBodyBytes = 10 * 1024 * 1024

private func collectBytes(_ bytes: URLSession.AsyncBytes) async throws -> String {
    var data = Data()
    for try await byte in bytes {
        data.append(byte)
        if data.count > maxResponseBodyBytes {
            throw ServiceError.providerMessage("Response exceeded maximum allowed size.")
        }
    }
    return String(decoding: data, as: UTF8.self)
}
