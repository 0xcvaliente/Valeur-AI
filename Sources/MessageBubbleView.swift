import AppKit
import SwiftUI

struct MessageBubbleView: View {
    let message: MessageRecord
    var onEditUserMessage: (() -> Void)? = nil
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
            HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 120)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: message.role == .user ? 6 : 14) {
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 12) {
                    if showsHeader {
                        HStack {
                            if let headerTitle {
                                Text(headerTitle)
                                    .font(AppTheme.headingFont(11, weight: .semibold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(roleAccent)
                            }
                            Spacer()
                        }
                    }

                    if message.role == .user {
                        messageContent(fullWidth: false)
                            .multilineTextAlignment(.trailing)
                    } else {
                        messageContent(fullWidth: true)
                    }
                }
                .modifier(MessageContainerStyle(role: message.role))
                .overlay(alignment: .topTrailing) {
                    if isHovering && message.role == .assistant {
                        copyButton
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                    }
                }

                if isHovering, message.role == .user, hasEditableText {
                    userActionRow
                }
            }
            .frame(
                maxWidth: contentMaxWidth,
                alignment: message.role == .user ? .trailing : .leading
            )
            .animation(.easeInOut(duration: 0.15), value: isHovering)

            if message.role != .user {
                Spacer(minLength: 120)
            }
        }
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private func messageContent(fullWidth: Bool) -> some View {
        if let attachmentsData = message.decryptedAttachmentsData {
            AttachmentImagesView(attachmentsData: attachmentsData)
        }

        ForEach(MarkdownBlock.parse(message.decryptedContent)) { block in
            switch block.kind {
            case .markdown(let markdown):
                MarkdownTextView(markdown: markdown, fullWidth: fullWidth)
            case .code(let language, let code):
                CodeBlockView(language: language, code: code)
            }
        }
    }

    private var showsHeader: Bool {
        message.role == .system
    }

    private var headerTitle: String? {
        switch message.role {
        case .system:
            "System"
        case .user:
            nil
        case .assistant:
            nil
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

    private var hasEditableText: Bool {
        !message.decryptedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var copyButton: some View {
        Button {
            copyMessageText()
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(AppTheme.uiFont(12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(AppTheme.surfacePrimary)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var editButton: some View {
        Button {
            onEditUserMessage?()
        } label: {
            Image(systemName: "pencil")
                .font(AppTheme.uiFont(12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(AppTheme.surfacePrimary)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var userActionRow: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            copyButton
            editButton
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing, 4)
    }

    private func copyMessageText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.decryptedContent, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
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
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        case .system:
            content
                .padding(18)
                .background(AppTheme.orange500.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        }
    }

}

struct MarkdownTextView: View {
    let markdown: String
    var fullWidth: Bool = true

    var body: some View {
        let mdOptions = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let baseText = (try? AttributedString(markdown: markdown, options: mdOptions))
            .map { Text($0) } ?? Text(markdown)
        let styled = baseText
            .font(AppTheme.uiFont(16, weight: .regular))
            .textSelection(.enabled)
            .foregroundStyle(AppTheme.textPrimary)
        if fullWidth {
            styled.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            styled
        }
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
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
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
