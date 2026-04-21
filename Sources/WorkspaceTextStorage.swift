import AppKit
import Foundation

struct WorkspaceTextDocumentData {
    let plainText: String
    let richTextData: Data?
}

enum WorkspaceTextStorage {
    static func document(from attributedString: NSAttributedString) -> WorkspaceTextDocumentData {
        let normalized = normalizedForEditor(attributedString)
        return WorkspaceTextDocumentData(
            plainText: normalized.string,
            richTextData: rtfData(from: normalized)
        )
    }

    static func document(fromMarkdown markdown: String) -> WorkspaceTextDocumentData {
        let html = MarkdownBlock.parse(markdown)
            .map { htmlFragment(for: $0) }
            .joined(separator: "\n")
        return document(fromHTML: html)
    }

    static func document(fromHTML html: String) -> WorkspaceTextDocumentData {
        document(from: attributedString(fromHTML: html) ?? NSAttributedString(string: html))
    }

    static func document(fromHTMLFragments fragments: [String]) -> WorkspaceTextDocumentData {
        document(fromHTML: fragments.joined(separator: "\n"))
    }

    static func attributedString(plainText: String, richTextData: Data?) -> NSAttributedString {
        if let richTextData,
            let attributed = try? NSAttributedString(
                data: richTextData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
            return normalizedForEditor(attributed)
        }

        return normalizedForEditor(
            attributedString(fromMarkdown: plainText) ?? NSAttributedString(string: plainText)
        )
    }

    static func htmlBody(plainText: String, richTextData: Data?) -> String {
        let attributed = attributedString(plainText: plainText, richTextData: richTextData)
        guard let htmlData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ),
        let html = String(data: htmlData, encoding: .utf8) else {
            return "<p>\(escapeHTML(plainText))</p>"
        }

        if let start = html.range(of: "<body[^>]*>", options: .regularExpression),
           let end = html.range(of: "</body>", options: .caseInsensitive) {
            return String(html[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return html
    }

    private static func attributedString(fromMarkdown markdown: String) -> NSAttributedString? {
        guard let attributed = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) else {
            return nil
        }

        return NSAttributedString(attributed)
    }

    private static func attributedString(fromHTML html: String) -> NSAttributedString? {
        let wrappedHTML: String
        if html.localizedCaseInsensitiveContains("<html") || html.localizedCaseInsensitiveContains("<body") {
            wrappedHTML = html
        } else {
            wrappedHTML = styledHTMLDocument(body: html)
        }

        guard let data = wrappedHTML.data(using: .utf8) else {
            return nil
        }

        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }

    static func htmlFragment(for block: MarkdownLayoutBlock) -> String {
        switch block.kind {
        case .heading(let level, let text):
            let headingLevel = min(max(level + 1, 2), 6)
            return "<h\(headingLevel)>\(escapeHTML(plainText(fromMarkdown: text)))</h\(headingLevel)>"
        case .paragraph(let text):
            return "<p>\(escapeHTML(plainText(fromMarkdown: text)))</p>"
        case .quote(let text):
            return "<blockquote>\(escapeHTML(plainText(fromMarkdown: text)))</blockquote>"
        case .divider:
            return "<hr>"
        case .remoteImage(let remoteImage):
            let caption = remoteImage.altText.trimmingCharacters(in: .whitespacesAndNewlines)
            let figcaption = caption.isEmpty ? "" : "<figcaption>\(escapeHTML(caption))</figcaption>"
            return "<figure><img src=\"\(escapeHTML(remoteImage.url.absoluteString))\" alt=\"\(escapeHTML(caption.isEmpty ? "Remote image" : caption))\">\(figcaption)</figure>"
        case .table(let table):
            return htmlTable(for: table)
        case .list(let items, let isOrdered):
            let tag = isOrdered ? "ol" : "ul"
            let listItems = items.map { "<li>\(escapeHTML(plainText(fromMarkdown: $0.text)))</li>" }.joined(separator: "")
            return "<\(tag)>\(listItems)</\(tag)>"
        }
    }

    static func htmlFragment(for block: MarkdownBlock) -> String {
        switch block.kind {
        case .markdown(let markdown):
            return MarkdownLayoutBlock.parse(markdown)
                .map { htmlFragment(for: $0) }
                .joined(separator: "\n")
        case .chart(let spec):
            return "<p>\(escapeHTML(spec.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? spec.title! : "Chart"))</p>"
        case .code(let language, let code):
            let label = language?.trimmingCharacters(in: .whitespacesAndNewlines)
            let header = (label?.isEmpty == false) ? "<p><strong>\(escapeHTML(label!))</strong></p>" : ""
            return "\(header)<pre><code>\(escapeHTML(code))</code></pre>"
        }
    }

    private static func rtfData(from attributedString: NSAttributedString) -> Data? {
        try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    static func normalizedForEditor(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else { return mutable }

        mutable.removeAttribute(.foregroundColor, range: fullRange)

        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            guard let font = value as? NSFont else {
                mutable.addAttribute(.font, value: AppTheme.uiNSFont(16, weight: .regular), range: range)
                return
            }

            let descriptor = font.fontDescriptor
            let traits = descriptor.symbolicTraits
            let size = font.pointSize > 0 ? font.pointSize : 16

            if traits.contains(.monoSpace) {
                mutable.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: size, weight: .regular), range: range)
                return
            }

            let normalizedSize = max(size, 10)
            let ref = AppTheme.uiNSFont(1, weight: traits.contains(.bold) ? .bold : .regular)
            let baseFont = NSFont(descriptor: ref.fontDescriptor, size: normalizedSize)
                ?? NSFont.systemFont(ofSize: normalizedSize, weight: traits.contains(.bold) ? .bold : .regular)
            let finalFont = traits.contains(.italic)
                ? NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                : baseFont
            mutable.addAttribute(.font, value: finalFont, range: range)
        }

        return mutable
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func plainText(fromMarkdown markdown: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else {
            return markdown
        }
        return String(attributed.characters)
    }

    private static func styledHTMLDocument(body: String) -> String {
        """
        <!doctype html>
        <html lang=\"en\">
        <head>
        <meta charset=\"utf-8\">
        <style>
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, \"SF Pro Text\", sans-serif;
            font-size: 16px;
            line-height: 1.55;
            color: #171513;
        }
        h1 {
            font-size: 30px;
            font-weight: 600;
            margin: 0 0 12px;
        }
        h2 {
            font-size: 28px;
            font-weight: 600;
            margin: 6px 0 12px;
        }
        h3 {
            font-size: 24px;
            font-weight: 600;
            margin: 4px 0 10px;
        }
        h4 {
            font-size: 20px;
            font-weight: 600;
            margin: 2px 0 8px;
        }
        h5 {
            font-size: 18px;
            font-weight: 600;
            margin: 2px 0 8px;
        }
        h6 {
            font-size: 16px;
            font-weight: 600;
            margin: 2px 0 8px;
        }
        p, li, blockquote {
            font-size: 16px;
            margin: 0 0 10px;
        }
        ul, ol {
            margin: 0 0 10px;
            padding-left: 22px;
        }
        li + li {
            margin-top: 6px;
        }
        blockquote {
            color: #71695f;
            border-left: 4px solid rgba(224, 109, 53, 0.35);
            padding: 10px 0 10px 12px;
        }
        hr {
            border: 0;
            border-top: 1px solid rgba(17, 17, 17, 0.10);
            margin: 8px 0;
        }
        pre {
            margin: 0 0 10px;
            padding: 12px 14px;
            background: #1d1b19;
            color: #f6f3ee;
            border-radius: 12px;
            white-space: pre-wrap;
        }
        code {
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 13px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 0 0 10px;
        }
        th, td {
            border: 1px solid rgba(17, 17, 17, 0.10);
            padding: 8px 10px;
            text-align: left;
            vertical-align: top;
            font-size: 15px;
        }
        th {
            background: rgba(244, 239, 230, 0.92);
            font-weight: 700;
        }
        .align-center {
            text-align: center;
        }
        .align-right {
            text-align: right;
        }
        figure {
            margin: 0 0 10px;
        }
        figcaption {
            margin-top: 6px;
            color: #71695f;
            font-size: 12px;
        }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private static func htmlTable(for table: MarkdownTable) -> String {
        let headers = zip(table.headers.indices, table.headers).map { index, header in
            let alignment = htmlAlignmentClass(for: table.alignments[safe: index] ?? .leading)
            return "<th class=\"\(alignment)\">\(escapeHTML(plainText(fromMarkdown: header)))</th>"
        }.joined(separator: "")

        let rows = table.rows.map { row in
            let columns = zip(row.indices, row).map { index, cell in
                let alignment = htmlAlignmentClass(for: table.alignments[safe: index] ?? .leading)
                return "<td class=\"\(alignment)\">\(escapeHTML(plainText(fromMarkdown: cell)))</td>"
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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
