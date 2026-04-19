import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ExportedFile {
    let data: Data
    let suggestedFilename: String
    let contentType: UTType
}

enum ConversationExportError: LocalizedError {
    case noConversation
    case emptyConversation
    case noTable
    case noVisual
    case invalidImageData
    case failedToEncodeHTML
    case failedToRenderPDF
    case failedToRenderPNG

    var errorDescription: String? {
        switch self {
        case .noConversation:
            return "Select a conversation before exporting."
        case .emptyConversation:
            return "There is nothing to export yet in this conversation."
        case .noTable:
            return "No table was found in the current conversation."
        case .noVisual:
            return "No image or chart was found in the current conversation."
        case .invalidImageData:
            return "The latest image could not be prepared for export."
        case .failedToEncodeHTML:
            return "The conversation could not be encoded as HTML."
        case .failedToRenderPDF:
            return "The conversation could not be rendered as a PDF."
        case .failedToRenderPNG:
            return "The visual could not be rendered as a PNG."
        }
    }
}

@MainActor
enum ConversationExportService {
    static func exportConversationHTML(_ conversation: ConversationRecord) throws -> ExportedFile {
        try ensureConversationHasMessages(conversation)
        let html = conversationHTMLDocument(for: conversation)
        guard let data = html.data(using: .utf8) else {
            throw ConversationExportError.failedToEncodeHTML
        }

        return ExportedFile(
            data: data,
            suggestedFilename: "\(safeFilenameStem(for: conversation.decryptedTitle)).html",
            contentType: .html
        )
    }

    static func exportConversationPDF(_ conversation: ConversationRecord) async throws -> ExportedFile {
        try ensureConversationHasMessages(conversation)
        let html = conversationHTMLDocument(for: conversation)
        let data = try await pdfData(fromHTML: html)

        return ExportedFile(
            data: data,
            suggestedFilename: "\(safeFilenameStem(for: conversation.decryptedTitle)).pdf",
            contentType: .pdf
        )
    }

    static func exportLatestTableCSV(_ conversation: ConversationRecord) throws -> ExportedFile {
        try ensureConversationHasMessages(conversation)
        guard let table = latestTable(in: conversation) else {
            throw ConversationExportError.noTable
        }

        return ExportedFile(
            data: Data(csvString(for: table).utf8),
            suggestedFilename: "\(safeFilenameStem(for: conversation.decryptedTitle))-table.csv",
            contentType: .commaSeparatedText
        )
    }

    static func exportLatestVisualPNG(_ conversation: ConversationRecord) async throws -> ExportedFile {
        try ensureConversationHasMessages(conversation)
        guard let visual = latestVisual(in: conversation) else {
            throw ConversationExportError.noVisual
        }

        let data: Data
        switch visual {
        case .attachment(let attachment):
            data = try pngData(from: attachment.data)
        case .remoteImage(let remoteImage):
            let (downloadedData, response) = try await URLSession.shared.data(from: remoteImage.url)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw ConversationExportError.invalidImageData
            }
            data = try pngData(from: downloadedData)
        case .chart(let spec):
            data = try pngData(for: spec)
        }

        return ExportedFile(
            data: data,
            suggestedFilename: "\(safeFilenameStem(for: conversation.decryptedTitle))-visual.png",
            contentType: .png
        )
    }

    static func hasTable(in conversation: ConversationRecord?) -> Bool {
        guard let conversation else { return false }
        return latestTable(in: conversation) != nil
    }

    static func hasVisual(in conversation: ConversationRecord?) -> Bool {
        guard let conversation else { return false }
        return latestVisual(in: conversation) != nil
    }

    static func safeFilenameStem(for title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = trimmedTitle.isEmpty ? "conversation" : trimmedTitle
        let normalized = baseTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = normalized.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(sanitized)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()

        return collapsed.isEmpty ? "conversation" : String(collapsed.prefix(64))
    }

    static func csvString(for table: MarkdownTable) -> String {
        ([table.headers] + table.rows)
            .map { row in row.map(csvField).joined(separator: ",") }
            .joined(separator: "\n")
    }

    static func chartFallbackTable(for spec: MarkdownChartSpec) -> MarkdownTable {
        let labelHeader = normalized(spec.xLabel) ?? "Label"
        let valueHeader = normalized(spec.yLabel) ?? "Value"

        if spec.hasSeries {
            return MarkdownTable(
                headers: ["Series", labelHeader, valueHeader],
                alignments: [.leading, .leading, .trailing],
                rows: spec.data.map { point in
                    [point.normalizedSeries ?? "", point.label, numberString(point.value)]
                }
            )
        }

        return MarkdownTable(
            headers: [labelHeader, valueHeader],
            alignments: [.leading, .trailing],
            rows: spec.data.map { point in
                [point.label, numberString(point.value)]
            }
        )
    }

    private static func ensureConversationHasMessages(_ conversation: ConversationRecord) throws {
        guard !sortedMessages(in: conversation).isEmpty else {
            throw ConversationExportError.emptyConversation
        }
    }

    private static func latestTable(in conversation: ConversationRecord) -> MarkdownTable? {
        for message in sortedMessages(in: conversation).reversed() {
            for markdownBlock in MarkdownBlock.parse(message.decryptedContent).reversed() {
                guard case .markdown(let markdown) = markdownBlock.kind else { continue }
                for block in MarkdownLayoutBlock.parse(markdown).reversed() {
                    if case .table(let table) = block.kind {
                        return table
                    }
                }
            }
        }

        return nil
    }

    private static func latestVisual(in conversation: ConversationRecord) -> LatestVisual? {
        for message in sortedMessages(in: conversation).reversed() {
            if let attachments = decodedAttachments(for: message) {
                for attachment in attachments.reversed() where attachment.mimeType.hasPrefix("image/") {
                    return .attachment(attachment)
                }
            }

            for markdownBlock in MarkdownBlock.parse(message.decryptedContent).reversed() {
                switch markdownBlock.kind {
                case .chart(let spec):
                    return .chart(spec)
                case .markdown(let markdown):
                    for block in MarkdownLayoutBlock.parse(markdown).reversed() {
                        if case .remoteImage(let remoteImage) = block.kind {
                            return .remoteImage(remoteImage)
                        }
                    }
                case .code:
                    continue
                }
            }
        }

        return nil
    }

    private static func sortedMessages(in conversation: ConversationRecord) -> [MessageRecord] {
        conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })
    }

    private static func decodedAttachments(for message: MessageRecord) -> [MessageAttachment]? {
        guard let data = message.decryptedAttachmentsData else {
            return nil
        }
        return try? JSONDecoder().decode([MessageAttachment].self, from: data)
    }

    private static func conversationHTMLDocument(for conversation: ConversationRecord) -> String {
        let title = plainText(from: conversation.decryptedTitle)
        let messageHTML = sortedMessages(in: conversation)
            .map(htmlMessage)
            .joined(separator: "\n")
        let providerLine = "\(conversation.provider.displayName) · \(conversation.provider.normalizedModelIdentifier(conversation.modelIdentifier))"

        return """
        <!doctype html>
        <html lang=\"en\">
        <head>
        <meta charset=\"utf-8\">
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
        <title>\(escapeHTML(title))</title>
        <style>
        :root {
            color-scheme: light;
            --bg: #f7f5f0;
            --surface: #ffffff;
            --surface-alt: #f4efe6;
            --border: rgba(17, 17, 17, 0.10);
            --text: #171513;
            --muted: #71695f;
            --accent: #e06d35;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, \"SF Pro Text\", sans-serif;
            color: var(--text);
            background: linear-gradient(180deg, #f7f3ed 0%, var(--bg) 100%);
        }
        main {
            width: min(980px, calc(100vw - 40px));
            margin: 0 auto;
            padding: 40px 0 56px;
        }
        header {
            margin-bottom: 28px;
            padding: 26px 28px;
            border: 1px solid var(--border);
            border-radius: 22px;
            background: rgba(255,255,255,0.72);
        }
        header h1 {
            margin: 0 0 8px;
            font-size: 32px;
            line-height: 1.1;
        }
        header p {
            margin: 0;
            color: var(--muted);
            font-size: 14px;
        }
        .conversation {
            display: grid;
            gap: 18px;
        }
        .message {
            border: 1px solid var(--border);
            border-radius: 22px;
            background: var(--surface);
            padding: 20px 22px;
        }
        .message.user {
            background: var(--surface-alt);
        }
        .message header {
            margin: 0 0 14px;
            padding: 0;
            border: 0;
            border-radius: 0;
            background: transparent;
        }
        .message-role {
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.10em;
            text-transform: uppercase;
            color: var(--accent);
        }
        .message-body {
            display: grid;
            gap: 14px;
        }
        p, li, blockquote, td, th {
            font-size: 15px;
            line-height: 1.6;
        }
        h2, h3, h4, h5, h6 {
            margin: 0;
            line-height: 1.2;
        }
        p, ul, ol, blockquote, table, pre, figure {
            margin: 0;
        }
        blockquote {
            padding: 12px 14px;
            border-left: 4px solid rgba(224, 109, 53, 0.35);
            background: rgba(244, 239, 230, 0.92);
            color: var(--muted);
            border-radius: 12px;
        }
        hr {
            border: 0;
            border-top: 1px solid var(--border);
            margin: 2px 0;
        }
        ul, ol {
            padding-left: 22px;
        }
        li + li {
            margin-top: 8px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            overflow: hidden;
            border: 1px solid var(--border);
            border-radius: 16px;
        }
        th, td {
            border-bottom: 1px solid var(--border);
            padding: 10px 12px;
            text-align: left;
            vertical-align: top;
        }
        th {
            background: rgba(244, 239, 230, 0.92);
            font-size: 13px;
            font-weight: 700;
        }
        tr:last-child td {
            border-bottom: 0;
        }
        .align-center { text-align: center; }
        .align-right { text-align: right; }
        pre {
            padding: 14px 16px;
            border-radius: 16px;
            background: #1d1b19;
            color: #f6f3ee;
            overflow-x: auto;
        }
        code {
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 13px;
        }
        .attachment-grid {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
        }
        .attachment-card {
            border: 1px solid var(--border);
            border-radius: 16px;
            background: rgba(244, 239, 230, 0.72);
            padding: 12px;
            width: fit-content;
            max-width: 100%;
        }
        .attachment-card img {
            display: block;
            max-width: min(100%, 520px);
            border-radius: 12px;
        }
        .attachment-card a {
            color: var(--accent);
            text-decoration: none;
            font-weight: 600;
        }
        .chart-card {
            border: 1px solid var(--border);
            border-radius: 18px;
            background: rgba(244, 239, 230, 0.72);
            padding: 16px;
            display: grid;
            gap: 12px;
        }
        .chart-card h3 {
            font-size: 18px;
        }
        .chart-subtitle {
            color: var(--muted);
            font-size: 13px;
        }
        figure img {
            display: block;
            max-width: min(100%, 720px);
            border-radius: 16px;
        }
        figcaption {
            margin-top: 8px;
            color: var(--muted);
            font-size: 12px;
        }
        </style>
        </head>
        <body>
        <main>
            <header>
                <h1>\(escapeHTML(title))</h1>
                <p>Exported from Valeur AI · \(escapeHTML(providerLine))</p>
            </header>
            <section class=\"conversation\">
                \(messageHTML)
            </section>
        </main>
        </body>
        </html>
        """
    }

    private static func htmlMessage(for message: MessageRecord) -> String {
        let roleLabel: String = switch message.role {
        case .assistant: "Assistant"
        case .user: "You"
        case .system: "System"
        }

        var bodyComponents: [String] = []

        if let attachments = decodedAttachments(for: message), !attachments.isEmpty {
            bodyComponents.append(htmlForAttachments(attachments))
        }

        for block in MarkdownBlock.parse(message.decryptedContent) {
            bodyComponents.append(html(for: block))
        }

        if bodyComponents.isEmpty {
            bodyComponents.append("<p>&nbsp;</p>")
        }

        return """
        <article class=\"message \(message.role.rawValue)\">
            <header>
                <div class=\"message-role\">\(escapeHTML(roleLabel))</div>
            </header>
            <div class=\"message-body\">
                \(bodyComponents.joined(separator: "\n"))
            </div>
        </article>
        """
    }

    private static func htmlForAttachments(_ attachments: [MessageAttachment]) -> String {
        let cards = attachments.map { attachment in
            if attachment.mimeType.hasPrefix("image/") {
                return """
                <div class=\"attachment-card\">
                    <img src=\"\(dataURL(for: attachment))\" alt=\"Attachment\">
                </div>
                """
            }

            return """
            <div class=\"attachment-card\">
                <a href=\"\(dataURL(for: attachment))\">Attached PDF</a>
            </div>
            """
        }

        return "<div class=\"attachment-grid\">\(cards.joined(separator: "\n"))</div>"
    }

    private static func html(for block: MarkdownBlock) -> String {
        switch block.kind {
        case .markdown(let markdown):
            return MarkdownLayoutBlock.parse(markdown)
                .map(html)
                .joined(separator: "\n")
        case .chart(let spec):
            let table = chartFallbackTable(for: spec)
            let title = normalized(spec.title) ?? "Chart"
            let subtitle = normalized(spec.subtitle).map { "<div class=\"chart-subtitle\">\(escapeHTML($0))</div>" } ?? ""
            return """
            <section class=\"chart-card\">
                <div>
                    <h3>\(escapeHTML(title))</h3>
                    \(subtitle)
                </div>
                \(htmlTable(for: table))
            </section>
            """
        case .code(let language, let code):
            let label = language?.trimmingCharacters(in: .whitespacesAndNewlines)
            let header = (label?.isEmpty == false) ? "<div class=\"chart-subtitle\">\(escapeHTML(label!))</div>" : ""
            return """
            <section>
                \(header)
                <pre><code>\(escapeHTML(code))</code></pre>
            </section>
            """
        }
    }

    private static func html(for block: MarkdownLayoutBlock) -> String {
        switch block.kind {
        case .heading(let level, let text):
            let headingLevel = min(max(level + 1, 2), 6)
            return "<h\(headingLevel)>\(escapeHTML(plainText(from: text)))</h\(headingLevel)>"
        case .paragraph(let text):
            return "<p>\(escapeHTML(plainText(from: text)))</p>"
        case .quote(let text):
            return "<blockquote>\(escapeHTML(plainText(from: text)))</blockquote>"
        case .divider:
            return "<hr>"
        case .remoteImage(let remoteImage):
            let caption = remoteImage.altText.trimmingCharacters(in: .whitespacesAndNewlines)
            let figcaption = caption.isEmpty ? "" : "<figcaption>\(escapeHTML(caption))</figcaption>"
            return """
            <figure>
                <img src=\"\(escapeHTML(remoteImage.url.absoluteString))\" alt=\"\(escapeHTML(caption.isEmpty ? "Remote image" : caption))\">
                \(figcaption)
            </figure>
            """
        case .table(let table):
            return htmlTable(for: table)
        case .list(let items, let isOrdered):
            let tag = isOrdered ? "ol" : "ul"
            let listItems = items.map { "<li>\(escapeHTML(plainText(from: $0.text)))</li>" }.joined(separator: "")
            return "<\(tag)>\(listItems)</\(tag)>"
        }
    }

    private static func htmlTable(for table: MarkdownTable) -> String {
        let headers = zip(table.headers.indices, table.headers).map { index, header in
            let alignment = htmlAlignmentClass(for: table.alignments[safe: index] ?? .leading)
            return "<th class=\"\(alignment)\">\(escapeHTML(plainText(from: header)))</th>"
        }.joined(separator: "")

        let rows = table.rows.map { row in
            let columns = zip(row.indices, row).map { index, cell in
                let alignment = htmlAlignmentClass(for: table.alignments[safe: index] ?? .leading)
                return "<td class=\"\(alignment)\">\(escapeHTML(plainText(from: cell)))</td>"
            }.joined(separator: "")
            return "<tr>\(columns)</tr>"
        }.joined(separator: "")

        return "<table><thead><tr>\(headers)</tr></thead><tbody>\(rows)</tbody></table>"
    }

    private static func htmlAlignmentClass(for alignment: MarkdownTableAlignment) -> String {
        switch alignment {
        case .leading:
            return "align-left"
        case .center:
            return "align-center"
        case .trailing:
            return "align-right"
        }
    }

    private static func plainText(from markdown: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else {
            return markdown
        }
        return String(attributed.characters)
    }

    private static func dataURL(for attachment: MessageAttachment) -> String {
        "data:\(attachment.mimeType);base64,\(attachment.data.base64EncodedString())"
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func csvField(_ value: String) -> String {
        let normalizedValue = plainText(from: value)
        let escaped = normalizedValue.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func numberString(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func pngData(from imageData: Data) throws -> Data {
        guard let image = NSImage(data: imageData) else {
            throw ConversationExportError.invalidImageData
        }
        return try pngData(from: image)
    }

    private static func pngData(from image: NSImage) throws -> Data {
        guard let tiffRepresentation = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ConversationExportError.failedToRenderPNG
        }
        return data
    }

    private static func pngData(for chartSpec: MarkdownChartSpec) throws -> Data {
        let content = MarkdownChartView(spec: chartSpec)
            .frame(width: 900)
            .padding(24)
            .background(AppTheme.backgroundPrimary)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else {
            throw ConversationExportError.failedToRenderPNG
        }
        return try pngData(from: image)
    }

    private static func pdfData(fromHTML html: String) async throws -> Data {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 1400))
        let delegate = ExportWebViewNavigationDelegate()
        webView.navigationDelegate = delegate
        webView.loadHTMLString(html, baseURL: nil)
        try await delegate.waitForCompletion()

        return try await withCheckedThrowingContinuation { continuation in
            let configuration = WKPDFConfiguration()
            webView.createPDF(configuration: configuration) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure:
                    continuation.resume(throwing: ConversationExportError.failedToRenderPDF)
                }
            }
        }
    }

    private enum LatestVisual {
        case attachment(MessageAttachment)
        case remoteImage(MarkdownRemoteImage)
        case chart(MarkdownChartSpec)
    }
}

private final class ExportWebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func waitForCompletion() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume(returning: ())
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
