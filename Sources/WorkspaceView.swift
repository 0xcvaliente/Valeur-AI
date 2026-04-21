import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView {
            workspaceSidebar
        } detail: {
            workspaceDetail
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(settingsStore.appAppearance.colorScheme)
        .background(WindowAppearanceSynchronizer(colorScheme: settingsStore.appAppearance.colorScheme))
        .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    }

    private var workspaceSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(AppTheme.uiFont(12, weight: .semibold))
                        Text("Chat")
                            .font(AppTheme.uiFont(13, weight: .medium))
                    }
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                .help("Back to Chat")

                Text("Workspace")
                    .font(AppTheme.headingFont(20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 0)

                Button {
                    viewModel.createBlankWorkspace()
                } label: {
                    Image(systemName: "plus")
                        .font(AppTheme.uiFont(13, weight: .bold))
                }
                .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))
                .help("New Workspace")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            List(selection: selectedWorkspaceID) {
                ForEach(viewModel.workspaces) { workspace in
                    WorkspaceSidebarRow(workspace: workspace)
                        .tag(workspace.id)
                }
            }
            .listStyle(.sidebar)
        }
        .background(AppTheme.sidebarGrey.opacity(0.94))
        .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 360)
    }

    @ViewBuilder
    private var workspaceDetail: some View {
        if let selectedWorkspace = viewModel.selectedWorkspace {
            WorkspaceEditorView(viewModel: viewModel, workspace: selectedWorkspace)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "square.split.2x1")
                    .font(AppTheme.headingFont(40, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("No Workspace Selected")
                    .font(AppTheme.headingFont(24, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Create a blank workspace or open a chat response into the editor to start iterating on text, tables, charts, and images.")
                    .font(AppTheme.uiFont(14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)

                Button("New Workspace") {
                    viewModel.createBlankWorkspace()
                }
                .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.backgroundPrimary)
        }
    }

    private var selectedWorkspaceID: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedWorkspace?.id },
            set: { newID in
                let target = viewModel.workspaces.first(where: { $0.id == newID })
                DispatchQueue.main.async {
                    viewModel.selectWorkspace(target)
                }
            }
        )
    }
}

private struct WorkspaceSidebarRow: View {
    let workspace: WorkspaceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(displayTitle)
                .font(AppTheme.uiFont(13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            Text(relativeTimestamp)
                .font(AppTheme.uiFont(11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var displayTitle: String {
        let trimmed = workspace.decryptedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Workspace" : trimmed
    }

    private var relativeTimestamp: String {
        workspace.updatedAt.formatted(.relative(presentation: .named))
    }
}

private struct WorkspaceEditorView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let workspace: WorkspaceRecord
    @State private var isShowingDeleteWorkspaceAlert = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(sortedBlocks) { block in
                        WorkspaceBlockCardView(viewModel: viewModel, block: block)
                    }
                }
                .padding(24)
            }
            .background(AppTheme.backgroundPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sortedBlocks: [WorkspaceBlockRecord] {
        workspace.blocks.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    private var header: some View {
        HStack(spacing: 14) {
            TextField(
                "Untitled Workspace",
                text: Binding(
                    get: { workspace.decryptedTitle },
                    set: { viewModel.renameSelectedWorkspace($0) }
                )
            )
            .textFieldStyle(.plain)
            .font(AppTheme.headingFont(24, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)

            Spacer(minLength: 0)

            Menu {
                Button("Workspace as PDF") {
                    Task { await viewModel.exportSelectedWorkspacePDF() }
                }
                .disabled(!viewModel.canExportSelectedWorkspaceDocument)

                Button("Workspace as DOCX") {
                    Task { await viewModel.exportSelectedWorkspaceDOCX() }
                }
                .disabled(!viewModel.canExportSelectedWorkspaceDocument)

                Button("Workspace as HTML") {
                    Task { await viewModel.exportSelectedWorkspaceHTML() }
                }
                .disabled(!viewModel.canExportSelectedWorkspaceDocument)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))

            Menu {
                ForEach(WorkspaceBlockKind.allCases) { kind in
                    Button {
                        viewModel.addBlock(kind)
                    } label: {
                        Label(kind.title, systemImage: kind.icon)
                    }
                }
            } label: {
                Label("Add Block", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))

            Button(role: .destructive) {
                isShowingDeleteWorkspaceAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(AppTheme.surfacePrimary)
        .alert("Delete Workspace?", isPresented: $isShowingDeleteWorkspaceAlert) {
            Button("Delete", role: .destructive) {
                viewModel.deleteSelectedWorkspace()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the selected workspace and all of its blocks.")
        }
    }
}

private struct WorkspaceBlockCardView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let block: WorkspaceBlockRecord
    @State private var isShowingRevisionSheet = false
    @State private var isShowingHistorySheet = false
    @State private var isShowingDeleteBlockAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Label(block.kind.title, systemImage: block.kind.icon)
                    .font(AppTheme.uiFont(13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                Spacer(minLength: 0)

                if viewModel.canRevise(block) {
                    Button {
                        isShowingRevisionSheet = true
                    } label: {
                        Label("Revise", systemImage: "sparkles")
                    }
                    .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))
                    .disabled(viewModel.revisingBlockID != nil && !viewModel.isRevising(block))
                }

                if !block.sortedRevisions.isEmpty {
                    Button {
                        isShowingHistorySheet = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                }

                if viewModel.canExportCSV(block) {
                    Button {
                        Task { await viewModel.exportBlockCSV(block) }
                    } label: {
                        Label("CSV", systemImage: "tablecells.badge.ellipsis")
                    }
                    .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))

                    Button {
                        Task { await viewModel.exportBlockXLSX(block) }
                    } label: {
                        Label("XLSX", systemImage: "tablecells")
                    }
                    .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                }

                if viewModel.canExportPNG(block) {
                    Button {
                        Task { await viewModel.exportBlockPNG(block) }
                    } label: {
                        Label("PNG", systemImage: "photo.badge.arrow.down")
                    }
                    .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                }

                Button(role: .destructive) {
                    isShowingDeleteBlockAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(AppTheme.uiFont(12, weight: .bold))
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                .help("Remove block")
            }

            switch block.kind {
            case .text:
                WorkspaceTextBlockEditorView(
                    block: block,
                    onChange: { plainText, richTextData in
                        viewModel.updateTextBlock(block, plainText: plainText, richTextData: richTextData)
                    },
                    onImport: { viewModel.importTextFile(into: block, from: $0) }
                )
            case .table:
                WorkspaceTableBlockEditorView(
                    table: block.workspaceTable,
                    onChange: { viewModel.updateTableBlock(block, table: $0) },
                    onImportCSV: { viewModel.importCSVFile(into: block, from: $0) }
                )
            case .chart:
                WorkspaceChartBlockEditorView(
                    json: Binding(
                        get: { block.decryptedContent },
                        set: { viewModel.updateChartBlock(block, chartJSON: $0) }
                    ),
                    onImportJSON: { viewModel.importChartJSONFile(into: block, from: $0) }
                )
            case .image:
                WorkspaceImageBlockEditorView(
                    payload: block.workspaceImagePayload,
                    localImageData: block.decryptedAttachmentsData,
                    onChange: { viewModel.updateImageBlock(block, payload: $0) },
                    onImportImage: { viewModel.importImageFile(into: block, from: $0) }
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .sheet(isPresented: $isShowingRevisionSheet) {
            WorkspaceRevisionSheet(viewModel: viewModel, block: block)
                .frame(width: 620, height: 520)
                .presentationBackground(AppTheme.backgroundPrimary)
        }
        .sheet(isPresented: $isShowingHistorySheet) {
            WorkspaceRevisionHistorySheet(viewModel: viewModel, block: block)
                .frame(width: 720, height: 620)
                .presentationBackground(AppTheme.backgroundPrimary)
        }
        .alert("Delete Block?", isPresented: $isShowingDeleteBlockAlert) {
            Button("Delete", role: .destructive) {
                viewModel.deleteBlock(block)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the selected block from the workspace.")
        }
    }
}

private final class WorkspaceTextFormatController: ObservableObject {
    weak var textView: NSTextView?

    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false
    @Published var fontSize: CGFloat = 16
    @Published var canUndo = false
    @Published var canRedo = false

    func updateState() {
        guard let textView else {
            DispatchQueue.main.async { [weak self] in
                self?.canUndo = false
                self?.canRedo = false
            }
            return
        }
        let attrs: [NSAttributedString.Key: Any]
        if textView.selectedRange().length > 0,
           textView.textStorage?.length ?? 0 > 0,
           textView.selectedRange().location < (textView.textStorage?.length ?? 0) {
            attrs = textView.textStorage?.attributes(at: textView.selectedRange().location, effectiveRange: nil) ?? textView.typingAttributes
        } else {
            attrs = textView.typingAttributes
        }
        let font = attrs[.font] as? NSFont
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        let newBold = traits.contains(.bold)
        let newItalic = traits.contains(.italic)
        let newUnderline = (attrs[.underlineStyle] as? Int ?? 0) != 0
        let newSize = font?.pointSize ?? 16
        let newCanUndo = textView.undoManager?.canUndo ?? false
        let newCanRedo = textView.undoManager?.canRedo ?? false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isBold = newBold
            self.isItalic = newItalic
            self.isUnderline = newUnderline
            self.fontSize = newSize
            self.canUndo = newCanUndo
            self.canRedo = newCanRedo
        }
    }

    private func restoreFocus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    func undo() {
        guard let textView else { return }
        textView.undoManager?.undo()
        restoreFocus()
        updateState()
    }

    func redo() {
        guard let textView else { return }
        textView.undoManager?.redo()
        restoreFocus()
        updateState()
    }

    func toggleBold() {
        guard let textView else { return }
        let range = textView.selectedRange()
        if range.length > 0, NSMaxRange(range) <= textView.textStorage?.length ?? 0 {
            let snapshot = textView.textStorage?.attributedSubstring(from: range)
            textView.textStorage?.beginEditing()
            textView.textStorage?.enumerateAttribute(.font, in: range) { value, subRange, _ in
                let font = (value as? NSFont) ?? AppTheme.uiNSFont(16, weight: .regular)
                let newFont = font.fontDescriptor.symbolicTraits.contains(.bold)
                    ? NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                    : NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                textView.textStorage?.addAttribute(.font, value: newFont, range: subRange)
            }
            textView.textStorage?.endEditing()
            textView.didChangeText()
            if let snapshot {
                textView.undoManager?.registerUndo(withTarget: textView) { [weak self] tv in
                    tv.textStorage?.beginEditing()
                    tv.textStorage?.replaceCharacters(in: range, with: snapshot)
                    tv.textStorage?.endEditing()
                    tv.didChangeText()
                    self?.updateState()
                }
                textView.undoManager?.setActionName("Bold")
            }
        } else {
            let current = (textView.typingAttributes[.font] as? NSFont) ?? AppTheme.uiNSFont(16, weight: .regular)
            let newFont = current.fontDescriptor.symbolicTraits.contains(.bold)
                ? NSFontManager.shared.convert(current, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(current, toHaveTrait: .boldFontMask)
            textView.typingAttributes[.font] = newFont
        }
        restoreFocus()
        updateState()
    }

    func toggleItalic() {
        guard let textView else { return }
        let range = textView.selectedRange()
        if range.length > 0, NSMaxRange(range) <= textView.textStorage?.length ?? 0 {
            let snapshot = textView.textStorage?.attributedSubstring(from: range)
            textView.textStorage?.beginEditing()
            textView.textStorage?.enumerateAttribute(.font, in: range) { value, subRange, _ in
                let font = (value as? NSFont) ?? AppTheme.uiNSFont(16, weight: .regular)
                let newFont = font.fontDescriptor.symbolicTraits.contains(.italic)
                    ? NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
                    : NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                textView.textStorage?.addAttribute(.font, value: newFont, range: subRange)
            }
            textView.textStorage?.endEditing()
            textView.didChangeText()
            if let snapshot {
                textView.undoManager?.registerUndo(withTarget: textView) { [weak self] tv in
                    tv.textStorage?.beginEditing()
                    tv.textStorage?.replaceCharacters(in: range, with: snapshot)
                    tv.textStorage?.endEditing()
                    tv.didChangeText()
                    self?.updateState()
                }
                textView.undoManager?.setActionName("Italic")
            }
        } else {
            let current = (textView.typingAttributes[.font] as? NSFont) ?? AppTheme.uiNSFont(16, weight: .regular)
            let newFont = current.fontDescriptor.symbolicTraits.contains(.italic)
                ? NSFontManager.shared.convert(current, toNotHaveTrait: .italicFontMask)
                : NSFontManager.shared.convert(current, toHaveTrait: .italicFontMask)
            textView.typingAttributes[.font] = newFont
        }
        restoreFocus()
        updateState()
    }

    func toggleUnderline() {
        guard let textView else { return }
        let range = textView.selectedRange()
        if range.length > 0, NSMaxRange(range) <= textView.textStorage?.length ?? 0 {
            var hasUnderline = false
            textView.textStorage?.enumerateAttribute(.underlineStyle, in: range) { value, _, stop in
                if (value as? Int ?? 0) != 0 { hasUnderline = true; stop.pointee = true }
            }
            let snapshot = textView.textStorage?.attributedSubstring(from: range)
            textView.textStorage?.addAttribute(.underlineStyle, value: hasUnderline ? 0 : NSUnderlineStyle.single.rawValue, range: range)
            textView.didChangeText()
            if let snapshot {
                textView.undoManager?.registerUndo(withTarget: textView) { [weak self] tv in
                    tv.textStorage?.beginEditing()
                    tv.textStorage?.replaceCharacters(in: range, with: snapshot)
                    tv.textStorage?.endEditing()
                    tv.didChangeText()
                    self?.updateState()
                }
                textView.undoManager?.setActionName("Underline")
            }
        } else {
            let current = textView.typingAttributes[.underlineStyle] as? Int ?? 0
            textView.typingAttributes[.underlineStyle] = current != 0 ? 0 : NSUnderlineStyle.single.rawValue
        }
        restoreFocus()
        updateState()
    }

    func adjustFontSize(by delta: CGFloat) {
        guard let textView, let storage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 && NSMaxRange(selectedRange) <= storage.length {
            let snapshot = storage.attributedSubstring(from: selectedRange)
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: selectedRange) { value, subRange, _ in
                let font = (value as? NSFont) ?? AppTheme.uiNSFont(16, weight: .regular)
                let newSize = max(10, font.pointSize + delta)
                let newFont = NSFont(descriptor: font.fontDescriptor, size: newSize) ?? AppTheme.uiNSFont(newSize, weight: .regular)
                storage.addAttribute(.font, value: newFont, range: subRange)
            }
            storage.endEditing()
            textView.didChangeText()
            textView.undoManager?.registerUndo(withTarget: textView) { [weak self] tv in
                tv.textStorage?.beginEditing()
                tv.textStorage?.replaceCharacters(in: selectedRange, with: snapshot)
                tv.textStorage?.endEditing()
                tv.didChangeText()
                self?.updateState()
            }
            textView.undoManager?.setActionName("Font Size")
        } else {
            let current = (textView.typingAttributes[.font] as? NSFont) ?? AppTheme.uiNSFont(16, weight: .regular)
            let newSize = max(10, current.pointSize + delta)
            let newFont = NSFont(descriptor: current.fontDescriptor, size: newSize) ?? AppTheme.uiNSFont(newSize, weight: .regular)
            textView.typingAttributes[.font] = newFont
        }
        restoreFocus()
        updateState()
    }
}

private struct WorkspaceTextFormatBar: NSViewRepresentable {
    @ObservedObject var controller: WorkspaceTextFormatController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeNSView(context: Context) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = AppTheme.radius
        stack.layer?.cornerCurve = .continuous
        stack.layer?.borderWidth = 1

        let undoBtn   = makeButton("arrow.uturn.backward",    tag: 0, coordinator: context.coordinator)
        let redoBtn   = makeButton("arrow.uturn.forward",     tag: 1, coordinator: context.coordinator)
        let sep1      = makeSeparator()
        let boldBtn   = makeButton("bold",                    tag: 2, coordinator: context.coordinator)
        let italicBtn = makeButton("italic",                  tag: 3, coordinator: context.coordinator)
        let underBtn  = makeButton("underline",               tag: 4, coordinator: context.coordinator)
        let sep2      = makeSeparator()
        let decBtn    = makeButton("textformat.size.smaller", tag: 5, coordinator: context.coordinator)
        let sizeLabel = NSTextField(labelWithString: "16")
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        sizeLabel.alignment = .center
        sizeLabel.setContentHuggingPriority(.required, for: .horizontal)
        let incBtn    = makeButton("textformat.size.larger",  tag: 6, coordinator: context.coordinator)

        context.coordinator.undoBtn   = undoBtn
        context.coordinator.redoBtn   = redoBtn
        context.coordinator.boldBtn   = boldBtn
        context.coordinator.italicBtn = italicBtn
        context.coordinator.underBtn  = underBtn
        context.coordinator.sizeLabel = sizeLabel
        context.coordinator.sep1      = sep1
        context.coordinator.sep2      = sep2
        context.coordinator.stack     = stack

        for view in [undoBtn, redoBtn, sep1, boldBtn, italicBtn, underBtn, sep2, decBtn, sizeLabel, incBtn] {
            stack.addArrangedSubview(view)
        }
        return stack
    }

    func updateNSView(_ stack: NSView, context: Context) {
        let co = context.coordinator
        stack.effectiveAppearance.performAsCurrentDrawingAppearance {
            let surface = NSColor(AppTheme.surfacePrimary).cgColor
            let border  = NSColor(AppTheme.border).cgColor
            stack.layer?.backgroundColor = surface
            stack.layer?.borderColor = border
            co.sep1?.layer?.backgroundColor = border
            co.sep2?.layer?.backgroundColor = border
            applyEnabled(co.undoBtn, isEnabled: controller.canUndo)
            applyEnabled(co.redoBtn, isEnabled: controller.canRedo)
            applyActive(co.boldBtn,   isActive: controller.isBold)
            applyActive(co.italicBtn, isActive: controller.isItalic)
            applyActive(co.underBtn,  isActive: controller.isUnderline)
            co.sizeLabel?.textColor = NSColor(AppTheme.textSecondary)
        }
        co.sizeLabel?.stringValue = String(Int(controller.fontSize))
    }

    private func makeButton(_ symbol: String, tag: Int, coordinator: Coordinator) -> NSButton {
        let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let btn = NSButton()
        btn.refusesFirstResponder = true
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        btn.imageScaling = .scaleProportionallyDown
        btn.wantsLayer = true
        btn.layer?.cornerRadius = AppTheme.controlRadius
        btn.layer?.cornerCurve = .continuous
        btn.layer?.borderWidth = 1
        btn.tag = tag
        btn.target = coordinator
        btn.action = #selector(Coordinator.buttonTapped(_:))
        btn.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 30),
            btn.heightAnchor.constraint(equalToConstant: 26),
        ])
        return btn
    }

    private func makeSeparator() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: 1),
            v.heightAnchor.constraint(equalToConstant: 16),
        ])
        return v
    }

    private func applyEnabled(_ btn: NSButton?, isEnabled: Bool) {
        guard let btn else { return }
        btn.isEnabled = isEnabled
        btn.layer?.backgroundColor = NSColor(AppTheme.surfaceSecondary).cgColor
        btn.layer?.borderColor = NSColor(AppTheme.border).cgColor
        btn.contentTintColor = isEnabled ? NSColor(AppTheme.textPrimary) : NSColor(AppTheme.textSecondary).withAlphaComponent(0.45)
    }

    private func applyActive(_ btn: NSButton?, isActive: Bool) {
        guard let btn else { return }
        btn.isEnabled = true
        if isActive {
            btn.layer?.backgroundColor = NSColor(AppTheme.accent).cgColor
            btn.layer?.borderColor = NSColor(AppTheme.accent).cgColor
            btn.contentTintColor = .white
        } else {
            btn.layer?.backgroundColor = NSColor(AppTheme.surfaceSecondary).cgColor
            btn.layer?.borderColor = NSColor(AppTheme.border).cgColor
            btn.contentTintColor = NSColor(AppTheme.textPrimary)
        }
    }

    final class Coordinator: NSObject {
        let controller: WorkspaceTextFormatController
        weak var undoBtn:   NSButton?
        weak var redoBtn:   NSButton?
        weak var boldBtn:   NSButton?
        weak var italicBtn: NSButton?
        weak var underBtn:  NSButton?
        weak var sizeLabel: NSTextField?
        weak var sep1:      NSView?
        weak var sep2:      NSView?
        weak var stack:     NSView?

        init(controller: WorkspaceTextFormatController) { self.controller = controller }

        @objc func buttonTapped(_ sender: NSButton) {
            switch sender.tag {
            case 0: controller.undo()
            case 1: controller.redo()
            case 2: controller.toggleBold()
            case 3: controller.toggleItalic()
            case 4: controller.toggleUnderline()
            case 5: controller.adjustFontSize(by: -1)
            case 6: controller.adjustFontSize(by: 1)
            default: break
            }
        }
    }
}

private final class FormatControllerHolder: ObservableObject {
    let controller = WorkspaceTextFormatController()
}

private struct WorkspaceTextBlockEditorView: View {
    let block: WorkspaceBlockRecord
    let onChange: (String, Data?) -> Void
    let onImport: (URL) -> Void
    @State private var isImportingText = false
    @StateObject private var holder = FormatControllerHolder()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Import Text") {
                    isImportingText = true
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))

                Spacer(minLength: 0)
            }

            WorkspaceRichTextEditor(
                attributedString: block.workspaceTextAttributedString,
                formatController: holder.controller,
                onChange: { attributedString in
                    let document = WorkspaceTextStorage.document(from: attributedString)
                    onChange(document.plainText, document.richTextData)
                }
            )
            .frame(minHeight: 220)
            .background(AppTheme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))

            WorkspaceTextFormatBar(controller: holder.controller)
                .frame(height: 38)
        }
        .fileImporter(
            isPresented: $isImportingText,
            allowedContentTypes: [.plainText, .utf8PlainText, .text, UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                onImport(url)
            }
        }
    }
}

private final class WorkspaceNSTextView: NSTextView {
    let groupedUndoManager: GroupedTextUndoManager = {
        let um = GroupedTextUndoManager()
        um.groupsByEvent = false
        return um
    }()

    override var undoManager: UndoManager? { groupedUndoManager }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleMacTextDeletionShortcut(event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleMacTextDeletionShortcut(event) {
            return
        }

        super.keyDown(with: event)
    }

    override func doCommand(by selector: Selector) {
        if shouldCloseGroupedTextUndo(for: selector) {
            groupedUndoManager.closeGroupHandler?()
        }

        super.doCommand(by: selector)
    }

    private func handleMacTextDeletionShortcut(_ event: NSEvent) -> Bool {
        guard let selector = macTextDeletionSelector(for: event, allowsMarkedText: !hasMarkedText()) else {
            return false
        }

        doCommand(by: selector)
        return true
    }
}

private struct WorkspaceRichTextEditor: NSViewRepresentable {
    let attributedString: NSAttributedString
    let formatController: WorkspaceTextFormatController
    let onChange: (NSAttributedString) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, formatController: formatController)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = WorkspaceNSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(AppTheme.surfaceSecondary)
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.textPrimary)
        textView.font = AppTheme.uiNSFont(16, weight: .regular)
        textView.isRichText = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.importsGraphics = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 10, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.allowsUndo = true
        let coordinator = context.coordinator
        textView.groupedUndoManager.closeGroupHandler = { [weak textView, weak coordinator] in
            guard let tv = textView, let c = coordinator else { return }
            c.closeWordGroup(for: tv)
        }
        textView.textStorage?.setAttributedString(attributedString)
        context.coordinator.normalizeTypingAttributes(for: textView)
        context.coordinator.formatController.textView = textView
        if #available(macOS 15.0, *) {
            textView.writingToolsBehavior = .none
        }

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(AppTheme.surfaceSecondary)
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let backgroundColor = NSColor(AppTheme.surfaceSecondary)
        scrollView.backgroundColor = backgroundColor
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.textPrimary)
        textView.backgroundColor = backgroundColor
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        if context.coordinator.shouldApplyModelAttributedString(attributedString, to: textView) {
            context.coordinator.closeWordGroup(for: textView)
            textView.textStorage?.setAttributedString(attributedString)
        }
        context.coordinator.normalizeTypingAttributes(for: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let onChange: (NSAttributedString) -> Void
        let formatController: WorkspaceTextFormatController
        private var wordGroupOpen = false
        private var shouldCloseWordGroupAfterChange = false
        private var isTyping = false
        private var isSyncingLocalEdit = false

        init(onChange: @escaping (NSAttributedString) -> Void, formatController: WorkspaceTextFormatController) {
            self.onChange = onChange
            self.formatController = formatController
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacement = replacementString else {
                openWordGroupIfNeeded(for: textView)
                shouldCloseWordGroupAfterChange = true
                isTyping = false
                return true
            }
            let isWordBoundary = replacement.unicodeScalars.contains(where: {
                CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).contains($0)
            })
            let shouldTreatAsStandaloneEdit = replacement.isEmpty || replacement.count > 1 || isWordBoundary
            openWordGroupIfNeeded(for: textView)
            shouldCloseWordGroupAfterChange = shouldTreatAsStandaloneEdit
            isTyping = !shouldTreatAsStandaloneEdit
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            markLocalEditInFlight()
            normalizeTypingAttributes(for: textView)
            onChange(WorkspaceTextStorage.normalizedForEditor(textView.attributedString()))
            if shouldCloseWordGroupAfterChange {
                closeWordGroup(for: textView)
            }
            if NSEvent.pressedMouseButtons == 0 {
                formatController.updateState()
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if !isTyping {
                closeWordGroup(for: textView)
            }
            isTyping = false
            normalizeTypingAttributes(for: textView)
            if NSEvent.pressedMouseButtons == 0 {
                formatController.updateState()
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            closeWordGroup(for: textView)
            normalizeTypingAttributes(for: textView)
            if NSEvent.pressedMouseButtons == 0 {
                formatController.updateState()
            }
        }

        func closeWordGroup(for textView: NSTextView) {
            guard wordGroupOpen else { return }
            textView.undoManager?.endUndoGrouping()
            wordGroupOpen = false
            shouldCloseWordGroupAfterChange = false
        }

        private func openWordGroupIfNeeded(for textView: NSTextView) {
            guard !wordGroupOpen else { return }
            textView.undoManager?.beginUndoGrouping()
            wordGroupOpen = true
        }

        func shouldApplyModelAttributedString(_ attributedString: NSAttributedString, to textView: NSTextView) -> Bool {
            guard !textView.attributedString().isEqual(to: attributedString) else { return false }
            if isSyncingLocalEdit, textView.window?.firstResponder === textView {
                return false
            }
            return true
        }

        private func markLocalEditInFlight() {
            isSyncingLocalEdit = true
            DispatchQueue.main.async { [weak self] in
                self?.isSyncingLocalEdit = false
            }
        }

        func normalizeTypingAttributes(for textView: NSTextView) {
            var typingAttributes = textView.typingAttributes

            let currentFont = (typingAttributes[.font] as? NSFont) ?? textView.font ?? AppTheme.uiNSFont(16, weight: .regular)
            let traits = currentFont.fontDescriptor.symbolicTraits

            if traits.contains(.monoSpace) {
                typingAttributes[.font] = currentFont
            } else {
                let normalizedSize = max(currentFont.pointSize, 10)
                let ref = AppTheme.uiNSFont(1, weight: traits.contains(.bold) ? .bold : .regular)
                let baseFont = NSFont(descriptor: ref.fontDescriptor, size: normalizedSize)
                    ?? NSFont.systemFont(ofSize: normalizedSize, weight: traits.contains(.bold) ? .bold : .regular)
                typingAttributes[.font] = traits.contains(.italic)
                    ? NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                    : baseFont
            }

            typingAttributes[.foregroundColor] = NSColor(AppTheme.textPrimary)
            textView.typingAttributes = typingAttributes
        }
    }
}

private struct WorkspaceTableBlockEditorView: View {
    let table: MarkdownTable
    let onChange: (MarkdownTable) -> Void
    let onImportCSV: (URL) -> Void
    @State private var isImportingCSV = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button("Import CSV") {
                    isImportingCSV = true
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))

                Button("Add Row") {
                    var updated = table
                    updated.rows.append(Array(repeating: "", count: max(updated.headers.count, 1)))
                    onChange(updated)
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))

                Button("Add Column") {
                    var updated = table
                    updated.headers.append("Column \(updated.headers.count + 1)")
                    updated.alignments.append(.leading)
                    if updated.rows.isEmpty {
                        updated.rows = [Array(repeating: "", count: updated.headers.count)]
                    } else {
                        updated.rows = updated.rows.map { row in
                            var nextRow = row
                            nextRow.append("")
                            return nextRow
                        }
                    }
                    onChange(updated)
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(Array(table.headers.enumerated()), id: \.offset) { index, header in
                            TextField(
                                "Header",
                                text: Binding(
                                    get: { header },
                                    set: { newValue in
                                        var updated = table
                                        updated.headers[index] = newValue
                                        onChange(updated)
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                        }
                    }

                    ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                        HStack(spacing: 8) {
                            ForEach(Array(row.enumerated()), id: \.offset) { columnIndex, cell in
                                TextField(
                                    "Value",
                                    text: Binding(
                                        get: { cell },
                                        set: { newValue in
                                            var updated = table
                                            updated.rows[rowIndex][columnIndex] = newValue
                                            onChange(updated)
                                        }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)
                            }
                        }
                    }
                }
                .padding(14)
                .background(AppTheme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
            }
        }
        .fileImporter(
            isPresented: $isImportingCSV,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                onImportCSV(url)
            }
        }
    }
}

private struct WorkspaceChartBlockEditorView: View {
    @Binding var json: String
    let onImportJSON: (URL) -> Void
    @State private var isImportingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Import JSON") {
                    isImportingJSON = true
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    if let spec = WorkspaceSeedFactory.decodeChart(from: json) {
                        MarkdownChartView(spec: spec)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Invalid chart JSON", systemImage: "exclamationmark.triangle")
                                .font(AppTheme.uiFont(13, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)

                            Text("Fix the JSON spec to restore the live chart preview.")
                                .font(AppTheme.uiFont(12, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                TextEditor(text: $json)
                    .font(AppTheme.monoFont(13, weight: .regular))
                    .foregroundStyle(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minWidth: 320, minHeight: 320)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
            }
        }
        .fileImporter(
            isPresented: $isImportingJSON,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                onImportJSON(url)
            }
        }
    }
}

private struct WorkspaceImageBlockEditorView: View {
    let payload: WorkspaceImagePayload
    let localImageData: Data?
    let onChange: (WorkspaceImagePayload) -> Void
    let onImportImage: (URL) -> Void
    @State private var isImportingImage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            preview

            HStack {
                Button("Import Image") {
                    isImportingImage = true
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))

                Spacer(minLength: 0)
            }

            TextField(
                "Caption",
                text: Binding(
                    get: { payload.caption },
                    set: { newValue in
                        var updated = payload
                        updated.caption = newValue
                        onChange(updated)
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

            TextField(
                "Remote image URL",
                text: Binding(
                    get: { payload.remoteURLString ?? "" },
                    set: { newValue in
                        var updated = payload
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.remoteURLString = trimmed.isEmpty ? nil : trimmed
                        onChange(updated)
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

            if let remoteURL = payload.remoteURL {
                Button("Open Source") {
                    NSWorkspace.shared.open(remoteURL)
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
            }
        }
        .fileImporter(
            isPresented: $isImportingImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                onImportImage(url)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let localImageData, let image = NSImage(data: localImageData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 320)
                .background(AppTheme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        } else if let remoteURL = payload.remoteURL {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    workspaceImagePlaceholder(label: "Loading image...")
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                case .failure:
                    workspaceImagePlaceholder(label: "Could not load this image preview.")
                @unknown default:
                    workspaceImagePlaceholder(label: "Image preview unavailable.")
                }
            }
        } else {
            workspaceImagePlaceholder(label: "Add a remote image URL or open a chat image into this workspace.")
        }
    }

    private func workspaceImagePlaceholder(label: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "photo")
                .font(AppTheme.headingFont(28, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text(label)
                .font(AppTheme.uiFont(13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

private extension WorkspaceBlockRecord {
    var workspaceTextAttributedString: NSAttributedString {
        WorkspaceTextStorage.attributedString(plainText: decryptedContent, richTextData: decryptedAttachmentsData)
    }

    var workspaceTable: MarkdownTable {
        WorkspaceSeedFactory.decodeTable(from: decryptedContent) ?? MarkdownTable(
            headers: ["Column 1", "Column 2"],
            alignments: [.leading, .leading],
            rows: [["", ""]]
        )
    }

    var workspaceImagePayload: WorkspaceImagePayload {
        WorkspaceSeedFactory.decodeImagePayload(from: decryptedContent)
    }

    var sortedRevisions: [WorkspaceBlockRevisionRecord] {
        revisions.sorted(by: { $0.createdAt > $1.createdAt })
    }
}

private struct WorkspaceRevisionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkspaceViewModel
    let block: WorkspaceBlockRecord

    @State private var instruction = ""
    @State private var applyMode: WorkspaceRevisionApplyMode = .replace

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Revise \(block.kind.title) Block")
                    .font(AppTheme.headingFont(22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Using \(viewModel.revisionModelDisplayLabel)")
                    .font(AppTheme.uiFont(12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Revision Goal")
                    .font(AppTheme.uiFont(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                TextEditor(text: $instruction)
                    .font(AppTheme.uiFont(14, weight: .regular))
                    .foregroundStyle(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 140)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Ideas")
                    .font(AppTheme.uiFont(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                FlexibleSuggestionRow(suggestions: suggestions) { suggestion in
                    instruction = suggestion
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Apply Result")
                    .font(AppTheme.uiFont(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Picker("Apply Result", selection: $applyMode) {
                    ForEach(WorkspaceRevisionApplyMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(applyMode.subtitle)
                    .font(AppTheme.uiFont(12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if viewModel.isRevising(block) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.revisionStatusMessage ?? "Revising...")
                        .font(AppTheme.uiFont(12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Spacer(minLength: 0)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                .disabled(viewModel.isRevising(block))

                Button("Revise") {
                    Task {
                        if await viewModel.reviseBlock(block, instruction: instruction, applyMode: applyMode) {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))
                .disabled(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.revisingBlockID != nil)
            }
        }
        .padding(24)
    }

    private var suggestions: [String] {
        switch block.kind {
        case .text:
            return [
                "Make this shorter and more direct.",
                "Rewrite this for an executive audience.",
                "Turn this into a clearer checklist."
            ]
        case .table:
            return [
                "Clean the labels and sort the rows by impact.",
                "Add a more readable summary row.",
                "Restructure this table for a board update."
            ]
        case .chart:
            return [
                "Change this into a line chart and compare trends.",
                "Split this into series by region.",
                "Make the axis labels more presentation-ready."
            ]
        case .image:
            return []
        }
    }
}

private struct WorkspaceRevisionHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkspaceViewModel
    let block: WorkspaceBlockRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Revision History")
                    .font(AppTheme.headingFont(22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Restore an earlier version of this \(block.kind.title.lowercased()) block.")
                    .font(AppTheme.uiFont(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if block.sortedRevisions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(AppTheme.headingFont(28, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)

                    Text("No saved revisions yet.")
                        .font(AppTheme.uiFont(14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(block.sortedRevisions) { revision in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(revisionTitle(revision))
                                            .font(AppTheme.uiFont(13, weight: .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)

                                        Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(AppTheme.uiFont(11, weight: .medium))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer(minLength: 0)

                                    Button("Restore") {
                                        viewModel.restoreRevision(revision, to: block)
                                        dismiss()
                                    }
                                    .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))
                                }

                                Text(revisionPreview(revision))
                                    .font(AppTheme.uiFont(12, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(6)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                        }
                    }
                }
            }

            HStack {
                Spacer(minLength: 0)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
            }
        }
        .padding(24)
    }

    private func revisionTitle(_ revision: WorkspaceBlockRevisionRecord) -> String {
        let instruction = revision.decryptedInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        if !instruction.isEmpty {
            return instruction
        }

        if let provider = revision.provider, !revision.modelIdentifier.isEmpty {
            return "\(provider.displayName) · \(revision.modelIdentifier)"
        }

        return "Saved revision"
    }

    private func revisionPreview(_ revision: WorkspaceBlockRevisionRecord) -> String {
        switch block.kind {
        case .text:
            return WorkspaceTextStorage
                .attributedString(plainText: revision.decryptedContent, richTextData: revision.decryptedAttachmentsData)
                .string
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .table:
            if let table = WorkspaceSeedFactory.decodeTable(from: revision.decryptedContent) {
                let rowCount = table.rows.count
                let columnCount = table.headers.count
                let headerPreview = table.headers.joined(separator: " • ")
                return "\(columnCount) columns · \(rowCount) rows\n\(headerPreview)"
            }
            return "Table snapshot"
        case .chart:
            if let chart = WorkspaceSeedFactory.decodeChart(from: revision.decryptedContent) {
                let title = chart.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let titleText = (title?.isEmpty == false) ? title! : "Chart"
                return "\(titleText) · \(chart.type.rawValue.capitalized) · \(chart.data.count) data points"
            }
            return "Chart snapshot"
        case .image:
            let payload = WorkspaceSeedFactory.decodeImagePayload(from: revision.decryptedContent)
            return payload.caption.isEmpty ? "Image snapshot" : payload.caption
        }
    }
}

private struct FlexibleSuggestionRow: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button(suggestion) {
                    onSelect(suggestion)
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
            }
        }
    }
}
