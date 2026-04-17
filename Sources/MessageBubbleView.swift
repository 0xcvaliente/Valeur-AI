import AppKit
import SwiftUI

struct MessageBubbleView: View {
    let message: MessageRecord

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 120)
            }

            VStack(alignment: .leading, spacing: message.role == .assistant ? 14 : 12) {
                if showsHeader {
                    HStack {
                        if let headerTitle {
                            Text(headerTitle)
                                .font(AppTheme.headingFont(11, weight: .semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(roleAccent)
                        }

                        Spacer()

                        Text(message.createdAt, style: .time)
                            .font(AppTheme.monoFont(11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                messageContent
            }
            .modifier(MessageContainerStyle(role: message.role))
            .frame(maxWidth: contentMaxWidth, alignment: .leading)

            if message.role != .user {
                Spacer(minLength: 120)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if let attachmentsData = message.decryptedAttachmentsData {
            AttachmentImagesView(attachmentsData: attachmentsData)
        }

        ForEach(MarkdownBlock.parse(message.decryptedContent)) { block in
            switch block.kind {
            case .markdown(let markdown):
                MarkdownTextView(markdown: markdown, isUserMessage: message.role == .user)
            case .code(let language, let code):
                CodeBlockView(language: language, code: code)
            }
        }
    }

    private var showsHeader: Bool {
        message.role != .assistant
    }

    private var headerTitle: String? {
        switch message.role {
        case .user:
            nil
        case .assistant:
            nil
        case .system:
            "System"
        }
    }

    private var contentMaxWidth: CGFloat {
        switch message.role {
        case .user:
            760
        case .assistant:
            860
        case .system:
            760
        }
    }

    private var roleAccent: Color {
        message.role == .user ? AppTheme.textPrimary : AppTheme.textSecondary
    }
}

private struct MessageContainerStyle: ViewModifier {
    let role: Role

    func body(content: Content) -> some View {
        switch role {
        case .assistant:
            content
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
        case .user:
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.surfaceSecondary)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        case .system:
            content
                .padding(18)
                .background(AppTheme.blue500.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                        .strokeBorder(AppTheme.blue500.opacity(0.28), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        }
    }

}

struct MarkdownTextView: View {
    let markdown: String
    let isUserMessage: Bool

    var body: some View {
        let mdOptions = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: markdown, options: mdOptions) {
            Text(attributed)
                .font(AppTheme.uiFont(16, weight: .regular))
                .textSelection(.enabled)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(markdown)
                .font(AppTheme.uiFont(16, weight: .regular))
                .textSelection(.enabled)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var textColor: Color {
        isUserMessage ? AppTheme.textPrimary : AppTheme.textPrimary
    }
}

struct CodeBlockView: View {
    let language: String?
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language?.isEmpty == false ? language! : "Code")
                    .font(AppTheme.uiFont(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.textPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(AppTheme.codeFont(14))
                    .textSelection(.enabled)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(AppTheme.surfaceSecondary)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

private struct AttachmentImagesView: View {
    let attachmentsData: Data
    @State private var images: [NSImage] = []

    var body: some View {
        Group {
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            Image(nsImage: images[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .task(id: attachmentsData) {
            let data = attachmentsData
            let decoded: [NSImage] = await Task.detached(priority: .userInitiated) {
                guard let attachments = try? JSONDecoder().decode([MessageAttachment].self, from: data) else {
                    return []
                }
                return attachments.compactMap { NSImage(data: $0.data) }
            }.value
            images = decoded
        }
    }
}

struct MarkdownBlock: Identifiable {
    enum Kind {
        case markdown(String)
        case code(language: String?, code: String)
    }

    let id = UUID()
    let kind: Kind

    static func parse(_ source: String) -> [MarkdownBlock] {
        let source = source.count > 500_000 ? String(source.prefix(500_000)) : source
        guard !source.isEmpty else { return [.init(kind: .markdown(" "))] }

        let pattern = #"```([^\n`]*)\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.init(kind: .markdown(source))]
        }

        let nsRange = NSRange(source.startIndex..., in: source)
        let matches = regex.matches(in: source, range: nsRange)
        guard !matches.isEmpty else {
            return [.init(kind: .markdown(source))]
        }

        var blocks: [MarkdownBlock] = []
        var currentIndex = source.startIndex

        for match in matches {
            guard
                let wholeRange = Range(match.range(at: 0), in: source),
                let languageRange = Range(match.range(at: 1), in: source),
                let codeRange = Range(match.range(at: 2), in: source)
            else { continue }

            if currentIndex < wholeRange.lowerBound {
                let markdown = String(source[currentIndex..<wholeRange.lowerBound])
                if !markdown.isEmpty {
                    blocks.append(.init(kind: .markdown(markdown)))
                }
            }

            let language = String(source[languageRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let code = String(source[codeRange])
            blocks.append(.init(kind: .code(language: language.isEmpty ? nil : language, code: code)))
            currentIndex = wholeRange.upperBound
        }

        if currentIndex < source.endIndex {
            let markdown = String(source[currentIndex..<source.endIndex])
            if !markdown.isEmpty {
                blocks.append(.init(kind: .markdown(markdown)))
            }
        }

        return blocks.isEmpty ? [.init(kind: .markdown(source))] : blocks
    }
}
