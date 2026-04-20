import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject private var settingsStore: SettingsStore
    @Binding var text: String
    @Binding var draftAttachments: [URL]
    let isSending: Bool
    let onSubmit: () -> Void
    @State private var isImportingAttachment = false
    @State private var attachmentImportKind: AttachmentImportKind = .photos
    @State private var isShowingRemoteImageImporter = false
    @State private var remoteImageURL = ""
    @State private var isImportingRemoteImage = false
    @State private var textViewHeight: CGFloat = 38
    @State private var placeholderIndex = 0
    private let compactTextInset: CGFloat = 8
    private let placeholderRotationTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let chatPlaceholderPrompts: [String] = [
        "Ask me to summarize this conversation.",
        "Try: explain this like I am new to it.",
        "Write a draft reply, then make it shorter.",
        "Ask for code, notes, or a checklist.",
        "Tell me what to look for in this document."
    ]
    private let imagePlaceholderPrompts: [String] = [
        "Create a cinematic concept poster with dramatic lighting.",
        "Generate an isometric product render on a clean studio background.",
        "Make a warm editorial travel scene with realistic film grain.",
        "Design a bold album cover with geometric color blocking.",
        "Illustrate a futuristic dashboard floating above a city skyline."
    ]

    var body: some View {
        composerInputBox
            .onAppear {
                clearComposerFocus()
            }
            .onReceive(placeholderRotationTimer) { _ in
                guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    placeholderIndex = (placeholderIndex + 1) % currentPlaceholderPrompts.count
                }
            }
            .onChange(of: viewModel.composerMode) { _, _ in
                withAnimation(.easeInOut(duration: 0.18)) {
                    placeholderIndex = 0
                }
            }
            .fileImporter(
                isPresented: $isImportingAttachment,
                allowedContentTypes: attachmentImportKind.allowedContentTypes,
                allowsMultipleSelection: true
            ) { result in
                if let urls = try? result.get() {
                    viewModel.addImportedAttachments(urls)
                }
            }
            .sheet(isPresented: $isShowingRemoteImageImporter) {
                RemoteImageImportSheet(
                    urlText: $remoteImageURL,
                    isImporting: $isImportingRemoteImage,
                    onCancel: {
                        remoteImageURL = ""
                        isShowingRemoteImageImporter = false
                    },
                    onImport: {
                        let pendingURL = remoteImageURL
                        isImportingRemoteImage = true
                        Task {
                            let didImport = await viewModel.importRemoteImage(from: pendingURL)
                            await MainActor.run {
                                isImportingRemoteImage = false
                                if didImport {
                                    remoteImageURL = ""
                                    isShowingRemoteImageImporter = false
                                }
                            }
                        }
                    }
                )
                .frame(width: 460)
                .presentationBackground(AppTheme.backgroundPrimary)
            }
    }

    private var composerInputBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !draftAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(draftAttachments, id: \.self) { url in
                            ZStack(alignment: .topTrailing) {
                                if let nsImage = NSImage(contentsOf: url) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
                                } else {
                                    RoundedRectangle(cornerRadius: AppTheme.radius)
                                        .fill(AppTheme.surfaceSecondary)
                                        .frame(width: 56, height: 56)
                                        .overlay(Text(url.pathExtension.uppercased()).font(AppTheme.uiFont(11, weight: .medium)))
                                }
                                Button {
                                    viewModel.removeDraftAttachment(url)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .black)
                                        .background(Circle().fill(.white))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 64)
                .padding(.horizontal, 14)
                .padding(.top, 12)

                if viewModel.composerMode == .image {
                    Text("Attachments are not used for image generation yet. Remove them or switch back to chat mode.")
                        .font(AppTheme.uiFont(11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                } else if let draftAttachmentSupportMessage = viewModel.draftAttachmentSupportMessage {
                    Text(draftAttachmentSupportMessage)
                        .font(AppTheme.uiFont(11, weight: .medium))
                        .foregroundStyle(AppTheme.orange500)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                }
            }

            ZStack(alignment: .topLeading) {
                GrowingTextView(
                    text: $text,
                    measuredHeight: $textViewHeight,
                    minHeight: 38,
                    maxHeight: 120,
                    verticalInset: compactTextInset,
                    onSubmit: handlePrimaryAction
                )
                .frame(height: textViewHeight)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(currentPlaceholderPrompts[placeholderIndex])
                        .font(AppTheme.uiFont(16, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, compactTextInset + 1)
                        .padding(.leading, 16)
                        .padding(.trailing, 12)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .transition(.opacity)
                        .id(placeholderIndex)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 2)

            HStack(spacing: 6) {
                modeSelector

                if viewModel.composerMode == .chat {
                    Menu {
                        Button {
                            presentAttachmentImporter(.photos)
                        } label: {
                            Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                        }
                        .disabled(!viewModel.canUseVisionInput)

                        Button {
                            isShowingRemoteImageImporter = true
                        } label: {
                            Label("Add Image URL", systemImage: "link.badge.plus")
                        }
                        .disabled(!viewModel.canUseVisionInput)

                        Button {
                            presentAttachmentImporter(.pdf)
                        } label: {
                            Label("Add PDF", systemImage: "doc.richtext")
                        }
                        .disabled(!viewModel.canUseDocumentInput)
                    } label: {
                        ComposerCircleButton(icon: "plus")
                    }
                    .menuStyle(.borderlessButton)

                    Button { settingsStore.webSearchEnabled.toggle() } label: {
                        ComposerChipButton(
                            icon: "globe",
                            label: settingsStore.webSearchEnabled ? "Web Enabled" : "Web",
                            isActive: settingsStore.webSearchEnabled
                        )
                    }
                    .buttonStyle(.plain)

                    TokenContextBadge(
                        usageFraction: viewModel.tokenUsageFraction,
                        inputTokenCount: viewModel.inputTokenCount,
                        outputTokenCount: viewModel.outputTokenCount,
                        totalTokenCount: viewModel.estimatedTokenCount,
                        contextTokenLimit: viewModel.contextTokenLimit
                    )
                } else {
                    imageSizeSelector
                }

                Button {
                    startDictation()
                } label: {
                    ComposerCircleButton(icon: "mic.fill")
                }
                .buttonStyle(.plain)

                if viewModel.composerMode == .chat {
                    personalitySelector
                }

                llmSelector

                Spacer()

                Button(action: handlePrimaryAction) {
                    ComposerCircleButton(
                        icon: isSending ? "stop.fill" : "arrow.up",
                        isProminent: canSend || isSending,
                        iconForegroundColor: canSend || isSending ? .white : AppTheme.textSecondary
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !isSending)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                .fill(AppTheme.surfacePrimary)
        }
    }

    private var canSend: Bool {
        switch viewModel.composerMode {
        case .chat:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draftAttachments.isEmpty
        case .image:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var currentPlaceholderPrompts: [String] {
        viewModel.composerMode == .image ? imagePlaceholderPrompts : chatPlaceholderPrompts
    }

    private func presentAttachmentImporter(_ kind: AttachmentImportKind) {
        attachmentImportKind = kind
        isImportingAttachment = true
    }

    private func handlePrimaryAction() {
        if isSending {
            viewModel.cancelStreaming()
            return
        }

        guard canSend else { return }
        onSubmit()
    }

    private func startDictation() {
        NSApp.sendAction(Selector(("startDictation:")), to: nil, from: nil)
    }

    private func clearComposerFocus() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private var personalitySelector: some View {
        Menu {
            ForEach(ChatTone.allCases) { tone in
                Button {
                    settingsStore.chatTone = tone
                } label: {
                    HStack {
                        Label(tone.title, systemImage: tone.icon)
                        if settingsStore.chatTone == tone {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ComposerChipButton(
                icon: settingsStore.chatTone.icon,
                label: settingsStore.chatTone.title,
                isActive: settingsStore.chatTone != .balanced
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var llmSelector: some View {
        LLMSelectorMenu(viewModel: viewModel, settingsStore: settingsStore, style: .inline)
    }

    private var modeSelector: some View {
        HStack(spacing: 6) {
            modeButton(.chat, isDisabled: false)
            modeButton(.image, isDisabled: !viewModel.canUseImageGeneration)
        }
    }

    private func modeButton(_ mode: ComposerMode, isDisabled: Bool) -> some View {
        Button {
            viewModel.composerMode = mode
        } label: {
            ComposerChipButton(
                icon: mode.icon,
                label: mode.title,
                isActive: viewModel.composerMode == mode
            )
            .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(mode == .image && isDisabled ? "Image generation is currently available only when using an OpenAI model with image generation support." : "")
    }

    private var imageSizeSelector: some View {
        Menu {
            ForEach(ImageGenerationSize.allCases) { size in
                Button {
                    viewModel.imageGenerationSize = size
                } label: {
                    HStack {
                        Label(size.title, systemImage: size.icon)
                        if viewModel.imageGenerationSize == size {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ComposerChipButton(
                icon: viewModel.imageGenerationSize.icon,
                label: viewModel.imageGenerationSize.title,
                isActive: true
            )
        }
        .menuStyle(.borderlessButton)
        .help("Generated image size")
    }

}

private struct TokenContextBadge: View {
    let usageFraction: Double
    let inputTokenCount: Int
    let outputTokenCount: Int
    let totalTokenCount: Int
    let contextTokenLimit: Int
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Circle()
                    .stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: max(usageFraction, 0.01))
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.orange600, AppTheme.orange500, AppTheme.orange600],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 30, height: 30)

            if isHovered {
                TokenContextTooltip(
                    usageFraction: usageFraction,
                    inputTokenCount: inputTokenCount,
                    outputTokenCount: outputTokenCount,
                    totalTokenCount: totalTokenCount,
                    contextTokenLimit: contextTokenLimit
                )
                .offset(y: -42)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
                .zIndex(1)
            }
        }
        .frame(width: 34, height: 34)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovered)
    }

    private var tokenHelpText: String {
        "Context \(TokenFormatting.windowLabel(totalTokenCount)) / \(TokenFormatting.windowLabel(contextTokenLimit)) · \(TokenFormatting.percentLabel(for: usageFraction))\nIn \(TokenFormatting.compactCount(inputTokenCount))  Out \(TokenFormatting.compactCount(outputTokenCount))"
    }
}

private struct TokenContextTooltip: View {
    let usageFraction: Double
    let inputTokenCount: Int
    let outputTokenCount: Int
    let totalTokenCount: Int
    let contextTokenLimit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(TokenFormatting.percentLabel(for: usageFraction)) used (\(TokenFormatting.percentLabel(for: max(1 - usageFraction, 0))) left)")
            Text("\(TokenFormatting.compactCount(totalTokenCount)) / \(TokenFormatting.compactCount(contextTokenLimit)) tokens used")
            Text("Total usage \(TokenFormatting.compactCount(totalTokenCount))")
            Text("In \(TokenFormatting.compactCount(inputTokenCount))  Out \(TokenFormatting.compactCount(outputTokenCount))")
        }
        .font(AppTheme.uiFont(11, weight: .medium))
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surfacePrimary.opacity(0.98))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.textSecondary.opacity(0.10), lineWidth: 1)
        )
        .fixedSize()
        .allowsHitTesting(false)
    }
}

private enum AttachmentImportKind {
    case photos
    case pdf

    var allowedContentTypes: [UTType] {
        switch self {
        case .photos:
            return [.image]
        case .pdf:
            return [.pdf]
        }
    }
}

private struct RemoteImageImportSheet: View {
    @Binding var urlText: String
    @Binding var isImporting: Bool
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Import Image from URL")
                    .font(AppTheme.headingFont(20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Paste a direct image link to add it as a local draft attachment for image understanding.")
                    .font(AppTheme.uiFont(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("https://example.com/image.png", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .font(AppTheme.uiFont(14, weight: .regular))
                .disabled(isImporting)
                .onSubmit {
                    guard canImport else { return }
                    onImport()
                }

            HStack(spacing: 10) {
                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer(minLength: 0)

                Button("Cancel", action: onCancel)
                    .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                    .disabled(isImporting)

                Button("Import", action: onImport)
                    .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))
                    .disabled(!canImport || isImporting)
            }
        }
        .padding(22)
        .frame(minWidth: 420)
    }

    private var canImport: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Chip button

struct ComposerChipButton: View {
    let icon: String
    let label: String?
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(AppTheme.uiFont(12, weight: .semibold))
            if let label {
                Text(label)
                    .font(AppTheme.uiFont(12, weight: .semibold))
            }
        }
        .foregroundStyle(isActive ? AppTheme.orange500 : AppTheme.textSecondary)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            isActive
                ? AppTheme.orange500.opacity(0.10)
                : AppTheme.surfaceSecondary
        )
        .clipShape(Capsule())
    }
}

struct ComposerCircleButton: View {
    let icon: String
    var isProminent: Bool = false
    var iconForegroundColor: Color?

    var body: some View {
        let activeForeground = iconForegroundColor ?? (isProminent ? Color.white : AppTheme.textSecondary)

        ZStack {
            Circle()
                .fill(
                    isProminent
                        ? AnyShapeStyle(LinearGradient(
                            colors: [AppTheme.orange600, AppTheme.orange500],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(AppTheme.surfaceSecondary)
                )

            Image(systemName: icon)
                .font(AppTheme.uiFont(13, weight: .semibold))
                .foregroundStyle(activeForeground)
        }
        .frame(width: 34, height: 34)
    }
}

struct InlineLLMSelectorButton: View {
    let provider: LLMProvider
    let modelIdentifier: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cpu")
                .font(AppTheme.uiFont(12, weight: .semibold))
            Text(provider.selectorTitle)
                .font(AppTheme.uiFont(12, weight: .semibold))
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(AppTheme.uiFont(10, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(AppTheme.surfaceSecondary)
        .clipShape(Capsule())
        .help("Current model: \(provider.normalizedModelIdentifier(modelIdentifier))")
    }
}

// MARK: - Accessory button (kept for any remaining usages)

struct ComposerAccessoryButton: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(AppTheme.uiFont(15, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 36, height: 36)
            .background(AppTheme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

// MARK: - GrowingTextView

struct GrowingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let verticalInset: CGFloat
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            measuredHeight: $measuredHeight,
            minHeight: minHeight,
            maxHeight: maxHeight,
            verticalInset: verticalInset,
            onSubmit: onSubmit
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SubmitAwareTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.textPrimary)
        textView.font = AppTheme.uiNSFont(16, weight: .regular)
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.submitHandler = onSubmit
        if #available(macOS 15.0, *) {
            textView.writingToolsBehavior = .none
        }
        textView.textContainerInset = NSSize(width: 10, height: verticalInset)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        context.coordinator.recalculateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SubmitAwareTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = AppTheme.uiNSFont(16, weight: .regular)
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.textPrimary)
        textView.submitHandler = onSubmit
        textView.textContainerInset = NSSize(width: 10, height: verticalInset)
        context.coordinator.recalculateHeight(for: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var measuredHeight: CGFloat
        let minHeight: CGFloat
        let maxHeight: CGFloat
        let verticalInset: CGFloat
        let onSubmit: () -> Void

        init(
            text: Binding<String>,
            measuredHeight: Binding<CGFloat>,
            minHeight: CGFloat,
            maxHeight: CGFloat,
            verticalInset: CGFloat,
            onSubmit: @escaping () -> Void
        ) {
            self._text = text
            self._measuredHeight = measuredHeight
            self.minHeight = minHeight
            self.maxHeight = maxHeight
            self.verticalInset = verticalInset
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            recalculateHeight(for: textView)
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            recalculateHeight(for: textView)
        }

        func recalculateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
            let verticalInset = textView.textContainerInset.height * 2
            let resolvedHeight = min(max(ceil(usedHeight + verticalInset), minHeight), maxHeight)

            if abs(measuredHeight - resolvedHeight) > 0.5 {
                DispatchQueue.main.async {
                    self.measuredHeight = resolvedHeight
                }
            }
        }
    }
}

final class SubmitAwareTextView: NSTextView {
    var submitHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            submitHandler?()
        } else {
            super.keyDown(with: event)
        }
    }
}
