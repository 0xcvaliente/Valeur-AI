import AppKit
import Combine
import Foundation
import SwiftUI

struct ChatDetailView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var workspaceViewModel: WorkspaceViewModel
    let onOpenWorkspace: () -> Void

    var body: some View {
        ZStack {
            ChatSurfaceBackground()

            VStack(spacing: 0) {
                if isHomeState {
                    WelcomeHomeView(
                        viewModel: viewModel,
                        text: $viewModel.composerText,
                        draftAttachments: $viewModel.draftAttachments,
                        isSending: viewModel.isSending,
                        onSubmit: viewModel.sendCurrentMessage
                    )
                } else {
                    conversationView
                }
            }
            .padding(.horizontal, AppTheme.contentHorizontalPadding)
            .padding(.bottom, AppTheme.contentBottomPadding)
        }
    }

    private var conversationView: some View {
        VStack(spacing: AppTheme.sectionSpacing) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                        ForEach(sortedMessages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                MessageBubbleView(
                                    message: message,
                                    onEditUserMessage: { viewModel.editMessage(message) },
                                    onOpenInWorkspace: {
                                        if workspaceViewModel.createWorkspace(
                                            from: message,
                                            conversationTitle: viewModel.selectedConversation?.decryptedTitle
                                        ) != nil {
                                            onOpenWorkspace()
                                        }
                                    }
                                )
                                if message.id == sortedMessages.last?.id,
                                   message.role == .assistant,
                                   !viewModel.isSending,
                                   let duration = viewModel.lastGenerationDuration {
                                    HStack(spacing: 10) {
                                        Text("Generated in \(String(format: "%.1f", duration))s")
                                            .font(AppTheme.monoFont(11, weight: .medium))
                                            .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                                        Button(viewModel.retryActionLabel, action: viewModel.retryLastResponse)
                                            .disabled(!viewModel.canRetry)
                                            .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true))
                                            .font(AppTheme.uiFont(11, weight: .medium))
                                    }
                                    .padding(.leading, 4)
                                }
                            }
                            .id(message.id)
                        }
                        if viewModel.isSending {
                            StatusBubbleView(
                                status: viewModel.currentModelStatus,
                                startTime: viewModel.generationStartTime ?? Date()
                            )
                            .id("status_bubble")
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    resignComposerFocus()
                })
                .onChange(of: scrollTrigger) { _, _ in
                    scrollConversationToBottom(proxy)
                }
            }

            composerRow(maxWidth: 960)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sortedMessages: [MessageRecord] {
        (viewModel.selectedConversation?.messages ?? []).sorted(by: { $0.createdAt < $1.createdAt })
    }

    private var isHomeState: Bool {
        (viewModel.selectedConversation?.messages.isEmpty ?? true) && !viewModel.isSending
    }

    private var scrollTrigger: String {
        let lastMessage = sortedMessages.last
        return [
            lastMessage?.id.uuidString ?? "none",
            String(lastMessage?.decryptedContent.count ?? 0),
            viewModel.isSending ? "1" : "0",
            viewModel.currentModelStatus ?? ""
        ]
        .joined(separator: "|")
    }

    private func scrollConversationToBottom(_ proxy: ScrollViewProxy) {
        if let last = sortedMessages.last?.id {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(last, anchor: .bottom)
            }
            return
        }

        if viewModel.isSending {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo("status_bubble", anchor: .bottom)
            }
        }
    }

    private func resignComposerFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}

struct StatusBubbleView: View {
    let status: String?
    let startTime: Date
    @State private var isAnimating = false
    @State private var elapsed: TimeInterval = 0

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(AppTheme.uiFont(13, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .rotationEffect(.degrees(isAnimating ? 15 : -15))
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)

            Text(displayStatus)
                .font(AppTheme.uiFont(13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: status)

            Text(elapsedLabel)
                .font(AppTheme.monoFont(12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: elapsed)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { isAnimating = true }
        .onReceive(ticker) { _ in
            elapsed = Date().timeIntervalSince(startTime)
        }
    }

    private var displayStatus: String {
        if let status { return status }
        return elapsed < 3 ? "Thinking..." : "Gathering data..."
    }

    private var elapsedLabel: String {
        String(format: "%.1fs", elapsed)
    }
}

struct LLMSelectorMenu: View {
    enum Style { case header, inline, iconOnly }
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settingsStore: SettingsStore
    var style: Style = .header

    var body: some View {
        let currentProvider = viewModel.selectedConversation?.provider ?? settingsStore.defaultProvider
        let currentModelIdentifier = viewModel.selectedConversation?.modelIdentifier ?? settingsStore.selectedModel(for: currentProvider)
        let customModelIdentifiers = customModelIdentifiers(for: currentProvider, currentModelIdentifier: currentModelIdentifier)
        let selectProvider: (LLMProvider) -> Void = { provider in
            if viewModel.selectedConversation != nil {
                viewModel.updateProvider(provider)
            } else {
                settingsStore.defaultProvider = provider
            }
        }
        let selectModel: (String) -> Void = { modelIdentifier in
            if viewModel.selectedConversation != nil {
                viewModel.updateModel(modelIdentifier)
            } else {
                settingsStore.selectedModel = modelIdentifier
            }
        }

        Menu {
            Section("Providers") {
                ForEach(LLMProvider.allCases) { provider in
                    Button {
                        selectProvider(provider)
                    } label: {
                        ProviderSelectorMenuRow(
                            provider: provider,
                            modelIdentifier: settingsStore.selectedModel(for: provider),
                            isSelected: provider == currentProvider
                        )
                    }
                }
            }

            Divider()

            Section("\(currentProvider.displayName) Models") {
                ForEach(currentProvider.presets) { preset in
                    Button {
                        selectModel(preset.modelIdentifier)
                    } label: {
                        ModelSelectorMenuRow(
                            preset: preset,
                            isSelected: currentProvider.normalizedModelIdentifier(currentModelIdentifier) == preset.modelIdentifier
                        )
                    }
                }
            }

            if !customModelIdentifiers.isEmpty {
                Section("Saved Custom Models") {
                    ForEach(customModelIdentifiers, id: \.self) { modelIdentifier in
                        Button {
                            selectModel(modelIdentifier)
                        } label: {
                            CustomModelSelectorMenuRow(
                                provider: currentProvider,
                                modelIdentifier: modelIdentifier,
                                isSelected: currentProvider.normalizedModelIdentifier(currentModelIdentifier) == modelIdentifier
                            )
                        }
                    }
                }
            }
        } label: {
            switch style {
            case .inline:
                InlineLLMSelectorButton(
                    provider: currentProvider,
                    modelIdentifier: currentModelIdentifier
                )
                .toolbarTransparentPillChrome()
            case .iconOnly:
                ClusterIcon(systemName: "sparkles", isActive: false)
                    .toolbarTransparentCircleChrome()
            case .header:
                LLMSelectorButton(
                    provider: currentProvider,
                    modelIdentifier: currentModelIdentifier
                )
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(style == .iconOnly ? .hidden : .visible)
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func customModelIdentifiers(for provider: LLMProvider, currentModelIdentifier: String) -> [String] {
        let presetIdentifiers = Set(provider.presets.map(\.modelIdentifier))
        let candidates = [
            settingsStore.customModelIdentifier(for: provider),
            provider.normalizedModelIdentifier(currentModelIdentifier)
        ]

        var uniqueIdentifiers: [String] = []
        for candidate in candidates {
            let normalized = provider.normalizedModelIdentifier(candidate)
            if normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            if presetIdentifiers.contains(normalized) { continue }
            if uniqueIdentifiers.contains(normalized) { continue }
            uniqueIdentifiers.append(normalized)
        }

        return uniqueIdentifiers
    }
}

struct LLMSelectorButton: View {
    let provider: LLMProvider
    let modelIdentifier: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(AppTheme.headingFont(16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(AppTheme.uiFont(16, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(AppTheme.uiFont(11, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .headerControlStyle()
    }

    private var title: String {
        provider.selectorTitle
    }

    private var subtitle: String {
        provider.normalizedModelIdentifier(modelIdentifier)
    }
}

private struct HeaderControlStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                    .fill(AppTheme.surfacePrimary)
            )
    }
}

private extension View {
    func headerControlStyle() -> some View {
        modifier(HeaderControlStyleModifier())
    }
}

struct ProviderSelectorMenuRow: View {
    let provider: LLMProvider
    let modelIdentifier: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(AppTheme.headingFont(15, weight: .regular))
                Text(provider.normalizedModelIdentifier(modelIdentifier))
                    .font(AppTheme.uiFont(13, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Version \(provider.versionLabel(for: modelIdentifier))")
                    .font(AppTheme.uiFont(12, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Context \(TokenFormatting.windowLabel(provider.contextWindowTokens(for: modelIdentifier)))")
                    .font(AppTheme.uiFont(12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(AppTheme.uiFont(15, weight: .regular))
            }
        }
        .frame(minWidth: 260, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct ModelSelectorMenuRow: View {
    let preset: LLMModelPreset
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.title)
                    .font(AppTheme.headingFont(15, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("Version \(preset.versionLabel)")
                    .font(AppTheme.uiFont(12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(preset.subtitle)
                    .font(AppTheme.uiFont(13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("Context \(preset.contextWindowLabel)")
                    .font(AppTheme.uiFont(12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(AppTheme.uiFont(15, weight: .regular))
            }
        }
        .frame(minWidth: 260, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private struct CustomModelSelectorMenuRow: View {
    let provider: LLMProvider
    let modelIdentifier: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Model")
                    .font(AppTheme.headingFont(15, weight: .regular))
                    .lineLimit(1)
                Text(provider.normalizedModelIdentifier(modelIdentifier))
                    .font(AppTheme.uiFont(13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Version \(provider.versionLabel(for: modelIdentifier))")
                    .font(AppTheme.uiFont(12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Context \(TokenFormatting.windowLabel(provider.contextWindowTokens(for: modelIdentifier)))")
                    .font(AppTheme.uiFont(12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(AppTheme.uiFont(15, weight: .regular))
            }
        }
        .frame(minWidth: 260, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct WelcomeHomeView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @ObservedObject var viewModel: ChatViewModel
    @Binding var text: String
    @Binding var draftAttachments: [URL]
    let isSending: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            HStack(alignment: .center, spacing: 18) {
                ValeurLogoMark(size: 52)

                VStack(alignment: .leading, spacing: 6) {
                    Text(greetingTitle)
                        .font(AppTheme.headingFont(34, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Can I help you with anything?")
                        .font(AppTheme.headingFont(34, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }

            composerRow(maxWidth: 980)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var greetingTitle: String {
        let trimmedName = settingsStore.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hour = Calendar.current.component(.hour, from: Date())
        let period: String
        switch hour {
        case 5..<12: period = "Good Morning"
        case 12..<17: period = "Good Afternoon"
        case 17..<21: period = "Good Evening"
        default: period = "Good Night"
        }
        return trimmedName.isEmpty ? "\(period)." : "\(period), \(trimmedName)."
    }

    private func composerRow(maxWidth: CGFloat) -> some View {
        ComposerView(
            viewModel: viewModel,
            text: $text,
            draftAttachments: $draftAttachments,
            isSending: isSending,
            onSubmit: onSubmit
        )
        .frame(maxWidth: maxWidth)
        .overlay(alignment: .trailing) {
            if viewModel.composerMode == .chat {
                TokenContextBadge(
                    usageFraction: viewModel.tokenUsageFraction,
                    inputTokenCount: viewModel.inputTokenCount,
                    outputTokenCount: viewModel.outputTokenCount,
                    totalTokenCount: viewModel.estimatedTokenCount,
                    contextTokenLimit: viewModel.contextTokenLimit
                )
                .offset(x: 48)
            }
        }
    }
}

private extension ChatDetailView {
    func composerRow(maxWidth: CGFloat) -> some View {
        ComposerView(
            viewModel: viewModel,
            text: $viewModel.composerText,
            draftAttachments: $viewModel.draftAttachments,
            isSending: viewModel.isSending,
            onSubmit: viewModel.sendCurrentMessage
        )
        .frame(maxWidth: maxWidth)
        .overlay(alignment: .trailing) {
            if viewModel.composerMode == .chat {
                TokenContextBadge(
                    usageFraction: viewModel.tokenUsageFraction,
                    inputTokenCount: viewModel.inputTokenCount,
                    outputTokenCount: viewModel.outputTokenCount,
                    totalTokenCount: viewModel.estimatedTokenCount,
                    contextTokenLimit: viewModel.contextTokenLimit
                )
                .offset(x: 48)
            }
        }
    }
}


struct TokenUsageRingView: View {
    let usageFraction: Double
    let inputTokenCount: Int
    let outputTokenCount: Int
    let totalTokenCount: Int

    private let size: CGFloat = 96

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: max(usageFraction, 0.01))
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.accentDark, AppTheme.accent, AppTheme.accentDark],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(TokenFormatting.percentLabel(for: usageFraction))
                        .font(AppTheme.headingFont(17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("usage")
                        .font(AppTheme.uiFont(9, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(width: size, height: size)

            VStack(spacing: 2) {
                Text(usageLabel)
                    .font(AppTheme.monoFont(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(splitLabel)
                    .font(AppTheme.uiFont(9, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(width: 120)
    }

    private var usageLabel: String {
        "Used \(TokenFormatting.windowLabel(totalTokenCount))"
    }

    private var splitLabel: String {
        "In \(TokenFormatting.compactCount(inputTokenCount))  Out \(TokenFormatting.compactCount(outputTokenCount))"
    }
}

struct RotatingEarthView: View {
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.orange500.opacity(0.10))
                .blur(radius: 34)
                .frame(width: 164, height: 164)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.orange600,
                            AppTheme.orange700
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 72
                    )
                )
                .frame(width: 124, height: 124)
                .overlay {
                    EarthSurface()
                        .rotationEffect(.degrees(rotation))
                        .clipShape(Circle())
                }
                .shadow(color: AppTheme.orange500.opacity(0.28), radius: 42)
                .onAppear {
                    withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }
}

struct EarthSurface: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            AppTheme.orange500,
                            AppTheme.orange600,
                            AppTheme.orange700,
                            AppTheme.orange500
                        ],
                        center: .center
                    )
                )

            GlobeGrid()
                .stroke(AppTheme.borderStrong.opacity(0.7), lineWidth: 0.8)

            EarthContinentShape()
                .fill(Color.white.opacity(0.90))
                .blur(radius: 0.4)
                .offset(x: -10, y: -2)

            EarthContinentShape()
                .fill(Color.white.opacity(0.60))
                .scaleEffect(x: 0.62, y: 0.52)
                .offset(x: 24, y: 18)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blur(radius: 10)
        }
    }
}

struct GlobeGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        for factor in stride(from: 0.2, through: 0.8, by: 0.2) {
            let y = height * factor
            path.move(to: CGPoint(x: rect.minX + width * 0.1, y: y))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - width * 0.1, y: y),
                control: CGPoint(x: rect.midX, y: y + (factor < 0.5 ? -10 : 10))
            )
        }

        for factor in stride(from: 0.2, through: 0.8, by: 0.2) {
            let x = width * factor
            path.move(to: CGPoint(x: x, y: rect.minY + height * 0.08))
            path.addQuadCurve(
                to: CGPoint(x: x, y: rect.maxY - height * 0.08),
                control: CGPoint(x: x + (factor < 0.5 ? -10 : 10), y: rect.midY)
            )
        }
        return path
    }
}

struct EarthContinentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.34))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.24),
            control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.14),
            control2: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.14)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.42),
            control1: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.28),
            control2: CGPoint(x: rect.minX + rect.width * 0.54, y: rect.minY + rect.height * 0.34)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.58),
            control1: CGPoint(x: rect.minX + rect.width * 0.49, y: rect.minY + rect.height * 0.54),
            control2: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.58)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.34),
            control1: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.56),
            control2: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.44)
        )
        return path
    }
}

struct ChatSurfaceBackground: View {
    var body: some View {
        AppTheme.backgroundPrimary
            .ignoresSafeArea()
    }
}
