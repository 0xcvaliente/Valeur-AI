import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct MessageBubbleView: View {
    let message: MessageRecord
    var onEditUserMessage: (() -> Void)? = nil
    var onOpenInWorkspace: (() -> Void)? = nil
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
                        HStack(spacing: 8) {
                            if canOpenInWorkspace {
                                openWorkspaceButton
                            }
                            copyButton
                        }
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
        .contextMenu {
            if canOpenInWorkspace {
                Button("Open in Workspace") {
                    onOpenInWorkspace?()
                }
            }

            Button("Copy") {
                copyMessageText()
            }

            if message.role == .user, hasEditableText {
                Button("Edit Prompt") {
                    onEditUserMessage?()
                }
            }
        }
    }

    @ViewBuilder
    private func messageContent(fullWidth: Bool) -> some View {
        if let attachmentsData = message.decryptedAttachmentsData {
            AttachmentPreviewStrip(attachmentsData: attachmentsData)
        }

        ForEach(MarkdownBlock.parse(message.decryptedContent)) { block in
            switch block.kind {
            case .markdown(let markdown):
                MarkdownTextView(markdown: markdown, role: message.role, fullWidth: fullWidth)
            case .chart(let spec):
                MarkdownChartView(spec: spec)
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

    private var hasWorkspaceContent: Bool {
        hasEditableText || message.decryptedAttachmentsData != nil
    }

    private var canOpenInWorkspace: Bool {
        hasWorkspaceContent && onOpenInWorkspace != nil
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

    private var openWorkspaceButton: some View {
        Button {
            onOpenInWorkspace?()
        } label: {
            Image(systemName: "square.split.2x1")
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
            if canOpenInWorkspace {
                openWorkspaceButton
            }
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
    let role: Role
    var fullWidth: Bool = true

    var body: some View {
        if role == .user {
            let styled = inlineText(markdown, font: AppTheme.uiFont(16, weight: .regular))
            if fullWidth {
                styled.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                styled
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(MarkdownLayoutBlock.parse(markdown)) { block in
                    MarkdownStructuredBlockView(block: block)
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        }
    }

    private func inlineText(_ markdown: String, font: Font) -> some View {
        let mdOptions = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let baseText = (try? AttributedString(markdown: markdown, options: mdOptions))
            .map { Text($0) } ?? Text(markdown)
        return baseText
            .font(font)
            .textSelection(.enabled)
            .foregroundStyle(AppTheme.textPrimary)
            .lineSpacing(4)
    }
}

struct MarkdownLayoutBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case quote(String)
        case divider
        case remoteImage(MarkdownRemoteImage)
        case table(MarkdownTable)
        case list(items: [MarkdownListItem], isOrdered: Bool)
    }

    let id = UUID()
    let kind: Kind

    static func == (lhs: MarkdownLayoutBlock, rhs: MarkdownLayoutBlock) -> Bool {
        lhs.kind == rhs.kind
    }

    static func parse(_ source: String) -> [MarkdownLayoutBlock] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var blocks: [MarkdownLayoutBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let remoteImage = parseRemoteImage(trimmed) {
                blocks.append(.init(kind: .remoteImage(remoteImage)))
                index += 1
                continue
            }

            if let (table, nextIndex) = parseTable(lines: lines, startingAt: index) {
                blocks.append(.init(kind: .table(table)))
                index = nextIndex
                continue
            }

            if isDivider(trimmed) {
                blocks.append(.init(kind: .divider))
                index += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(.init(kind: .heading(level: heading.level, text: heading.text)))
                index += 1
                continue
            }

            if isQuoteLine(trimmed) {
                var quoteLines: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard isQuoteLine(current) else { break }
                    quoteLines.append(stripQuotePrefix(from: current))
                    index += 1
                }
                blocks.append(.init(kind: .quote(quoteLines.joined(separator: "\n"))))
                continue
            }

            if let firstListItem = parseListItem(trimmed) {
                let isOrdered = firstListItem.ordinal != nil
                var items = [firstListItem]
                index += 1

                while index < lines.count {
                    let rawLine = lines[index]
                    let current = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if current.isEmpty {
                        break
                    }

                    if let nextListItem = parseListItem(current), (nextListItem.ordinal != nil) == isOrdered {
                        items.append(nextListItem)
                        index += 1
                        continue
                    }

                    if let continuation = parseListContinuationLine(rawLine) {
                        let last = items.removeLast()
                        items.append(MarkdownListItem(ordinal: last.ordinal, text: last.text + " " + continuation))
                        index += 1
                        continue
                    }

                    break
                }

                blocks.append(.init(kind: .list(items: items, isOrdered: isOrdered)))
                continue
            }

            var paragraphLines = [trimmed]
            index += 1

            while index < lines.count {
                let current = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if current.isEmpty ||
                    parseRemoteImage(current) != nil ||
                    parseTable(lines: lines, startingAt: index) != nil ||
                    isDivider(current) ||
                    parseHeading(current) != nil ||
                    isQuoteLine(current) ||
                    parseListItem(current) != nil {
                    break
                }

                paragraphLines.append(current)
                index += 1
            }

            blocks.append(.init(kind: .paragraph(paragraphLines.joined(separator: " "))))
        }

        if blocks.isEmpty {
            return [.init(kind: .paragraph(source))]
        }

        return blocks
    }

    private static func parseRemoteImage(_ line: String) -> MarkdownRemoteImage? {
        if line.hasPrefix("!["),
           let closingBracketIndex = line.firstIndex(of: "]"),
           closingBracketIndex < line.endIndex,
           let openingParenIndex = line.index(closingBracketIndex, offsetBy: 1, limitedBy: line.endIndex),
           openingParenIndex < line.endIndex,
           line[openingParenIndex] == "(",
           line.hasSuffix(")") {
            let altStart = line.index(line.startIndex, offsetBy: 2)
            let altText = String(line[altStart..<closingBracketIndex])
            let urlStart = line.index(after: openingParenIndex)
            let urlEnd = line.index(before: line.endIndex)
            let urlString = String(line[urlStart..<urlEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = validatedRemoteImageURL(from: urlString) {
                return MarkdownRemoteImage(altText: altText, url: url)
            }
        }

        if let url = validatedRemoteImageURL(from: line) {
            return MarkdownRemoteImage(altText: "Remote image", url: url)
        }

        return nil
    }

    private static func parseTable(lines: [String], startingAt index: Int) -> (table: MarkdownTable, nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }

        let headerCells = splitTableRow(lines[index])
        let separatorCells = splitTableRow(lines[index + 1])

        guard headerCells.count >= 2,
              separatorCells.count == headerCells.count,
              separatorCells.allSatisfy(isTableSeparatorCell) else {
            return nil
        }

        var rows: [[String]] = []
        var rowIndex = index + 2
        while rowIndex < lines.count {
            let trimmed = lines[rowIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                break
            }

            let rowCells = splitTableRow(lines[rowIndex])
            guard rowCells.count >= 2 else {
                break
            }

            rows.append(normalizeTableCells(rowCells, expectedCount: headerCells.count))
            rowIndex += 1
        }

        guard !rows.isEmpty else { return nil }

        return (
            MarkdownTable(
                headers: normalizeTableCells(headerCells, expectedCount: headerCells.count),
                alignments: separatorCells.map(tableAlignment),
                rows: rows
            ),
            rowIndex
        )
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }
        let level = hashes.count
        guard (1...6).contains(level) else { return nil }

        let remainder = line.dropFirst(level)
        guard remainder.first == " " else { return nil }

        let text = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private static func parseListItem(_ line: String) -> MarkdownListItem? {
        if let marker = line.first,
           ["-", "*", "+"].contains(marker),
           line.count > 1,
           line[line.index(after: line.startIndex)] == " " {
            let remainder = line.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !remainder.isEmpty else { return nil }
            return MarkdownListItem(text: remainder)
        }

        var numberText = ""
        var index = line.startIndex
        while index < line.endIndex, line[index].isNumber {
            numberText.append(line[index])
            index = line.index(after: index)
        }

        guard !numberText.isEmpty,
              index < line.endIndex,
              line[index] == "." else {
            return nil
        }

        index = line.index(after: index)
        guard index < line.endIndex, line[index] == " " else { return nil }

        let text = line[line.index(after: index)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ordinal = Int(numberText), !text.isEmpty else { return nil }
        return MarkdownListItem(ordinal: ordinal, text: text)
    }

    private static func parseListContinuationLine(_ line: String) -> String? {
        guard line.hasPrefix("  ") || line.hasPrefix("\t") else { return nil }
        let continuation = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return continuation.isEmpty ? nil : continuation
    }

    private static func isQuoteLine(_ line: String) -> Bool {
        line.hasPrefix(">")
    }

    private static func stripQuotePrefix(from line: String) -> String {
        let withoutPrefix = line.dropFirst()
        return withoutPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isDivider(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        let unique = Set(compact)
        return unique == Set(["-"]) || unique == Set(["*"]) || unique == Set(["_"])
    }

    private static func validatedRemoteImageURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              isLikelyRemoteImageURL(url) else {
            return nil
        }
        return url
    }

    private static func isLikelyRemoteImageURL(_ url: URL) -> Bool {
        let extensionValue = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tif", "tiff", "heic", "heif", "avif"].contains(extensionValue)
    }

    private static func splitTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutLeadingPipe = trimmed.hasPrefix("|") ? String(trimmed.dropFirst()) : trimmed
        let content = withoutLeadingPipe.hasSuffix("|") ? String(withoutLeadingPipe.dropLast()) : withoutLeadingPipe
        return content
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func isTableSeparatorCell(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let core = trimmed.replacingOccurrences(of: ":", with: "")
        return core.count >= 3 && Set(core) == Set(["-"])
    }

    private static func tableAlignment(for separator: String) -> MarkdownTableAlignment {
        let trimmed = separator.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLeadingColon = trimmed.hasPrefix(":")
        let hasTrailingColon = trimmed.hasSuffix(":")

        switch (hasLeadingColon, hasTrailingColon) {
        case (true, true):
            return .center
        case (false, true):
            return .trailing
        default:
            return .leading
        }
    }

    private static func normalizeTableCells(_ cells: [String], expectedCount: Int) -> [String] {
        let normalized = Array(cells.prefix(expectedCount))
        if normalized.count == expectedCount {
            return normalized
        }
        return normalized + Array(repeating: "", count: expectedCount - normalized.count)
    }
}

struct MarkdownRemoteImage: Codable, Equatable, Sendable {
    let altText: String
    let url: URL
}

enum MarkdownTableAlignment: String, Codable, Equatable, Sendable {
    case leading
    case center
    case trailing

    var frameAlignment: Alignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

struct MarkdownTable: Codable, Equatable, Sendable {
    var headers: [String]
    var alignments: [MarkdownTableAlignment]
    var rows: [[String]]
}

struct MarkdownListItem: Identifiable, Equatable {
    let id = UUID()
    let ordinal: Int?
    let text: String

    init(ordinal: Int? = nil, text: String) {
        self.ordinal = ordinal
        self.text = text
    }

    static func == (lhs: MarkdownListItem, rhs: MarkdownListItem) -> Bool {
        lhs.ordinal == rhs.ordinal && lhs.text == rhs.text
    }
}

private struct MarkdownStructuredBlockView: View {
    let block: MarkdownLayoutBlock

    var body: some View {
        switch block.kind {
        case .heading(let level, let text):
            inlineText(text, font: headingFont(for: level))
                .padding(.top, level <= 2 ? 6 : 2)
        case .paragraph(let text):
            inlineText(text, font: AppTheme.uiFont(16, weight: .regular))
        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(AppTheme.orange500.opacity(0.35))
                    .frame(width: 4)

                inlineText(text, font: AppTheme.uiFont(15, weight: .medium), color: AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceSecondary.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        case .remoteImage(let remoteImage):
            MarkdownRemoteImageView(remoteImage: remoteImage)
        case .table(let table):
            MarkdownTableView(table: table)
        case .divider:
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
                .padding(.vertical, 2)
        case .list(let items, let isOrdered):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(isOrdered ? "\(item.ordinal ?? 1)." : "•")
                            .font(AppTheme.uiFont(14, weight: .semibold))
                            .foregroundStyle(AppTheme.orange500)
                            .frame(width: isOrdered ? 28 : 14, alignment: .leading)

                        inlineText(item.text, font: AppTheme.uiFont(16, weight: .regular))
                    }
                }
            }
        }
    }

    private func inlineText(_ markdown: String, font: Font, color: Color = AppTheme.textPrimary) -> some View {
        let mdOptions = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let baseText = (try? AttributedString(markdown: markdown, options: mdOptions))
            .map { Text($0) } ?? Text(markdown)
        return baseText
            .font(font)
            .textSelection(.enabled)
            .foregroundStyle(color)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return AppTheme.headingFont(28, weight: .semibold)
        case 2:
            return AppTheme.headingFont(24, weight: .semibold)
        case 3:
            return AppTheme.headingFont(20, weight: .semibold)
        case 4:
            return AppTheme.headingFont(18, weight: .semibold)
        case 5:
            return AppTheme.headingFont(16, weight: .semibold)
        default:
            return AppTheme.headingFont(15, weight: .semibold)
        }
    }
}

private struct MarkdownRemoteImageView: View {
    let remoteImage: MarkdownRemoteImage

    @State private var shouldLoadImage = false
    @State private var loadAttempt = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if shouldLoadImage {
                AsyncImage(url: remoteImage.url) { phase in
                    switch phase {
                    case .empty:
                        MarkdownRemoteImagePlaceholder(
                            title: displayTitle,
                            subtitle: hostLabel,
                            systemImage: "arrow.down.circle"
                        ) {
                            ProgressView()
                                .controlSize(.small)
                        }
                    case .success(let image):
                        VStack(alignment: .leading, spacing: 10) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 360, alignment: .leading)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))

                            HStack(spacing: 10) {
                                Text(hostLabel)
                                    .font(AppTheme.uiFont(11, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Button("Open") {
                                    NSWorkspace.shared.open(remoteImage.url)
                                }
                                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                            }
                        }
                    case .failure:
                        MarkdownRemoteImagePlaceholder(
                            title: displayTitle,
                            subtitle: "Could not load this image from \(hostLabel).",
                            systemImage: "exclamationmark.triangle"
                        ) {
                            Button("Retry") {
                                loadAttempt += 1
                            }
                            .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .id(loadAttempt)
            } else {
                MarkdownRemoteImagePlaceholder(
                    title: displayTitle,
                    subtitle: "External image from \(hostLabel). Loading it will fetch the file from the internet.",
                    systemImage: "photo.badge.arrow.down"
                ) {
                    HStack(spacing: 10) {
                        Button("Load Image") {
                            shouldLoadImage = true
                        }
                        .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))

                        Button("Open") {
                            NSWorkspace.shared.open(remoteImage.url)
                        }
                        .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                    }
                }
            }
        }
    }

    private var displayTitle: String {
        let trimmedAltText = remoteImage.altText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedAltText.isEmpty || trimmedAltText == "Remote image" ? "Remote image" : trimmedAltText
    }

    private var hostLabel: String {
        remoteImage.url.host ?? remoteImage.url.absoluteString
    }
}

private struct MarkdownRemoteImagePlaceholder<Accessory: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(AppTheme.uiFont(18, weight: .semibold))
                    .foregroundStyle(AppTheme.orange500)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.orange500.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.uiFont(15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(AppTheme.uiFont(12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            accessory
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

private struct MarkdownTableView: View {
    let table: MarkdownTable

    private let minimumColumnWidth: CGFloat = 140

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                tableRow(cells: table.headers, isHeader: true)

                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    tableRow(cells: row, isHeader: false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        }
    }

    @ViewBuilder
    private func tableRow(cells: [String], isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Text(cell.isEmpty ? " " : cell)
                    .font(isHeader ? AppTheme.uiFont(13, weight: .semibold) : AppTheme.uiFont(14, weight: .regular))
                    .foregroundStyle(isHeader ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .multilineTextAlignment(alignment(at: index).textAlignment)
                    .frame(width: minimumColumnWidth, alignment: alignment(at: index).frameAlignment)
                    .padding(.horizontal, 12)
                    .padding(.vertical, isHeader ? 10 : 11)
                    .background(backgroundColor(isHeader: isHeader, columnIndex: index))
            }
        }
    }

    private func backgroundColor(isHeader: Bool, columnIndex: Int) -> Color {
        if isHeader {
            return AppTheme.surfaceSecondary
        }
        return columnIndex.isMultiple(of: 2) ? AppTheme.surfacePrimary : AppTheme.surfaceSecondary.opacity(0.72)
    }

    private func alignment(at index: Int) -> MarkdownTableAlignment {
        guard index < table.alignments.count else { return .leading }
        return table.alignments[index]
    }
}

struct MarkdownChartSpec: Codable, Equatable, Sendable {
    enum ChartType: String, Codable, Equatable, Sendable {
        case bar
        case line
        case area
    }

    let type: ChartType
    let title: String?
    let subtitle: String?
    let xLabel: String?
    let yLabel: String?
    let data: [MarkdownChartPoint]

    var hasSeries: Bool {
        data.contains { ($0.series?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) }
    }
}

struct MarkdownChartPoint: Codable, Equatable, Identifiable, Sendable {
    let label: String
    let value: Double
    let series: String?

    var id: String {
        "\(series ?? "")|\(label)|\(value)"
    }

    var normalizedSeries: String? {
        let trimmed = series?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct MarkdownChartView: View {
    let spec: MarkdownChartSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = normalized(spec.title) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.headingFont(18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if let subtitle = normalized(spec.subtitle) {
                        Text(subtitle)
                            .font(AppTheme.uiFont(12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                chartBody
                    .frame(width: max(520, CGFloat(spec.data.count) * 72), height: 260)
            }

            if let xLabel = normalized(spec.xLabel) {
                Text(xLabel)
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }

    private var chartBody: some View {
        Chart(spec.data) { point in
            switch spec.type {
            case .bar:
                if let series = point.normalizedSeries {
                    BarMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .foregroundStyle(by: .value("Series", series))
                    .position(by: .value("Series", series))
                } else {
                    BarMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .foregroundStyle(AppTheme.orange500)
                }
            case .line:
                if let series = point.normalizedSeries {
                    LineMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Series", series))
                    PointMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .foregroundStyle(by: .value("Series", series))
                } else {
                    LineMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppTheme.orange500)
                    PointMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .foregroundStyle(AppTheme.orange500)
                }
            case .area:
                if let series = point.normalizedSeries {
                    AreaMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Series", series))
                    .opacity(0.35)
                    LineMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Series", series))
                } else {
                    AreaMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppTheme.orange500.opacity(0.32))
                    LineMark(
                        x: .value(normalized(spec.xLabel) ?? "Item", point.label),
                        y: .value(normalized(spec.yLabel) ?? "Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppTheme.orange500)
                }
            }
        }
        .chartLegend(spec.hasSeries ? .visible : .hidden)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYAxisLabel(position: .leading, alignment: .center) {
            if let yLabel = normalized(spec.yLabel) {
                Text(yLabel)
                    .font(AppTheme.uiFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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

private struct AttachmentPreview: Identifiable {
    let id: UUID
    let data: Data
    let image: NSImage?
    let mimeType: String
}

private struct AttachmentPreviewStrip: View {
    let attachmentsData: Data
    @State private var previews: [AttachmentPreview] = []

    var body: some View {
        Group {
            if !previews.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(previews) { preview in
                            if let image = preview.image {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
                                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                                    .contextMenu { attachmentActions(for: preview) }
                                    .onTapGesture(count: 2) {
                                        openAttachment(preview)
                                    }
                            } else {
                                AttachmentDocumentTile(mimeType: preview.mimeType)
                                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                                    .contextMenu { attachmentActions(for: preview) }
                                    .onTapGesture(count: 2) {
                                        openAttachment(preview)
                                    }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .task(id: attachmentsData) {
            let data = attachmentsData
            let decoded: [AttachmentPreview] = await Task.detached(priority: .userInitiated) {
                guard let attachments = try? JSONDecoder().decode([MessageAttachment].self, from: data) else {
                    return []
                }
                return attachments.map { attachment in
                    AttachmentPreview(
                        id: attachment.id,
                        data: attachment.data,
                        image: attachment.mimeType.hasPrefix("image/") ? NSImage(data: attachment.data) : nil,
                        mimeType: attachment.mimeType
                    )
                }
            }.value
            previews = decoded
        }
    }

    @ViewBuilder
    private func attachmentActions(for preview: AttachmentPreview) -> some View {
        Button("Open") {
            openAttachment(preview)
        }

        Button("Save As…") {
            saveAttachment(preview)
        }
    }

    private func openAttachment(_ preview: AttachmentPreview) {
        do {
            let url = try temporaryURL(for: preview)
            NSWorkspace.shared.open(url)
        } catch {
            NSSound.beep()
        }
    }

    private func saveAttachment(_ preview: AttachmentPreview) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename(for: preview)
        if let contentType = UTType(mimeType: preview.mimeType) {
            panel.allowedContentTypes = [contentType]
        }

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try preview.data.write(to: destinationURL, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }

    private func temporaryURL(for preview: AttachmentPreview) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension(for: preview.mimeType))
        try preview.data.write(to: url, options: .atomic)
        return url
    }

    private func suggestedFilename(for preview: AttachmentPreview) -> String {
        let prefix = preview.mimeType.hasPrefix("image/") ? "generated-image" : "attachment"
        return "\(prefix)-\(preview.id.uuidString.prefix(8)).\(fileExtension(for: preview.mimeType))"
    }

    private func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg":
            return "jpg"
        case "image/webp":
            return "webp"
        case "image/gif":
            return "gif"
        case "application/pdf":
            return "pdf"
        default:
            return "png"
        }
    }
}

private struct AttachmentDocumentTile: View {
    let mimeType: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mimeType == "application/pdf" ? "doc.richtext.fill" : "doc.fill")
                .font(AppTheme.uiFont(24, weight: .semibold))
                .foregroundStyle(AppTheme.orange500)

            Text(mimeType == "application/pdf" ? "PDF" : "File")
                .font(AppTheme.uiFont(11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(width: 80, height: 80)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

struct MarkdownBlock: Identifiable {
    enum Kind {
        case markdown(String)
        case chart(MarkdownChartSpec)
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
            if let chartSpec = parseChartSpec(language: language, code: code) {
                blocks.append(.init(kind: .chart(chartSpec)))
            } else {
                blocks.append(.init(kind: .code(language: language.isEmpty ? nil : language, code: code)))
            }
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

    private static func parseChartSpec(language: String, code: String) -> MarkdownChartSpec? {
        let normalizedLanguage = language
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        guard normalizedLanguage == "chart" || normalizedLanguage == "valeur-chart" || normalizedLanguage == "valeurchart" else {
            return nil
        }

        let chartData = Data(code.utf8)
        return try? JSONDecoder().decode(MarkdownChartSpec.self, from: chartData)
    }
}
