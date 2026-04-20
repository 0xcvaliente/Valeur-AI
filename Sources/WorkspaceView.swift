import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView {
            workspaceSidebar
        } detail: {
            workspaceDetail
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(nil)
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
                viewModel.selectWorkspace(viewModel.workspaces.first(where: { $0.id == newID }))
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
                    get: {
                        let trimmed = workspace.decryptedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? "Untitled Workspace" : trimmed
                    },
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
                    text: Binding(
                        get: { block.decryptedContent },
                        set: { viewModel.updateTextBlock(block, markdown: $0) }
                    ),
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

private struct WorkspaceTextBlockEditorView: View {
    @Binding var text: String
    let onImport: (URL) -> Void
    @State private var isImportingText = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Import Text") {
                    isImportingText = true
                }
                .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))

                Spacer(minLength: 0)
            }

            TextEditor(text: $text)
                .font(AppTheme.uiFont(15, weight: .regular))
                .foregroundStyle(AppTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 220)
                .background(AppTheme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
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
            return revision.decryptedContent.trimmingCharacters(in: .whitespacesAndNewlines)
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
