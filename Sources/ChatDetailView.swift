import Foundation
import SwiftUI

struct ChatDetailView: View {
    @ObservedObject var viewModel: ChatViewModel
    let isSidebarVisible: Bool
    let onSidebarToggle: () -> Void

    var body: some View {
        ZStack {
            ChatSurfaceBackground()

            VStack(spacing: 0) {
                topBar

                if isHomeState {
                    WelcomeHomeView(
                        provider: viewModel.selectedConversation?.provider ?? .openAI,
                        tokenUsageFraction: viewModel.tokenUsageFraction,
                        estimatedTokenCount: viewModel.estimatedTokenCount,
                        text: $viewModel.composerText,
                        draftAttachments: $viewModel.draftAttachments,
                        isSending: viewModel.isSending,
                        onSubmit: viewModel.sendCurrentMessage
                    )
                } else {
                    conversationView
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onSidebarToggle) {
                Image(systemName: isSidebarVisible ? "sidebar.leading" : "sidebar.left")
                    .font(AppTheme.uiFont(16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 56, height: 52)
                    .headerControlStyle()
            }
            .buttonStyle(.plain)

            Spacer()

            if !isHomeState {
                HStack(spacing: 10) {
                    Button("Retry", action: viewModel.retryLastResponse)
                        .disabled(viewModel.isSending || !viewModel.canRetry)

                    Button(viewModel.isSending ? "Stop" : "Stopped", action: viewModel.cancelStreaming)
                        .disabled(!viewModel.isSending)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .font(AppTheme.uiFont(14, weight: .medium))
        .foregroundStyle(AppTheme.textPrimary)
    }

    private var conversationView: some View {
        VStack(spacing: 18) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(sortedMessages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        if viewModel.isSending, let status = viewModel.currentModelStatus {
                            StatusBubbleView(status: status)
                                .id("status_bubble")
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 12)
                }
                .onChange(of: sortedMessages.map(\.id)) { _, ids in
                    if let last = ids.last {
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            ComposerDockView(
                text: $viewModel.composerText,
                draftAttachments: $viewModel.draftAttachments,
                isSending: viewModel.isSending,
                tokenUsageFraction: viewModel.tokenUsageFraction,
                estimatedTokenCount: viewModel.estimatedTokenCount,
                onSubmit: viewModel.sendCurrentMessage
            )
            .frame(maxWidth: 1020)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sortedMessages: [MessageRecord] {
        (viewModel.selectedConversation?.messages ?? []).sorted(by: { $0.createdAt < $1.createdAt })
    }

    private var isHomeState: Bool {
        (viewModel.selectedConversation?.messages.isEmpty ?? true) && !viewModel.isSending
    }
}

struct StatusBubbleView: View {
    let status: String
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(AppTheme.uiFont(14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .rotationEffect(.degrees(isAnimating ? 15 : -15))
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)

            Text(status)
                .font(AppTheme.uiFont(14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: status)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .onAppear {
            isAnimating = true
        }
    }
}

struct LLMSelectorMenu: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        if let conversation = viewModel.selectedConversation {
            Menu {
                ForEach(LLMProvider.allCases) { provider in
                    Button {
                        viewModel.updateProvider(provider)
                    } label: {
                        ProviderSelectorMenuRow(
                            provider: provider,
                            modelIdentifier: settingsStore.selectedModel(for: provider),
                            isSelected: provider == conversation.provider
                        )
                    }
                }
            } label: {
                LLMSelectorButton(
                    provider: conversation.provider,
                    modelIdentifier: conversation.modelIdentifier
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
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
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
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
                    .font(AppTheme.headingFont(15, weight: .semibold))
                Text(provider.normalizedModelIdentifier(modelIdentifier))
                    .font(AppTheme.uiFont(13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(AppTheme.uiFont(15, weight: .bold))
            }
        }
        .frame(minWidth: 260, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct WelcomeHomeView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    let provider: LLMProvider
    let tokenUsageFraction: Double
    let estimatedTokenCount: Int
    @Binding var text: String
    @Binding var draftAttachments: [URL]
    let isSending: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            VStack(spacing: 22) {
                RotatingEarthView()

                VStack(spacing: 10) {
                    Text(greetingTitle)
                    .font(AppTheme.headingFont(34, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    Text("Can I help you with anything ?")
                        .font(AppTheme.headingFont(34, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .multilineTextAlignment(.center)
            }

            ComposerDockView(
                text: $text,
                draftAttachments: $draftAttachments,
                isSending: isSending,
                tokenUsageFraction: tokenUsageFraction,
                estimatedTokenCount: estimatedTokenCount,
                onSubmit: onSubmit
            )
            .frame(maxWidth: 1040)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var greetingTitle: String {
        let trimmedName = settingsStore.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Good Evening."
        }
        return "Good Evening, \(trimmedName)."
    }
}

struct ComposerDockView: View {
    @Binding var text: String
    @Binding var draftAttachments: [URL]
    let isSending: Bool
    let tokenUsageFraction: Double
    let estimatedTokenCount: Int
    let onSubmit: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            ComposerView(
                text: $text,
                draftAttachments: $draftAttachments,
                isSending: isSending,
                onSubmit: onSubmit
            )

            TokenUsageRingView(
                usageFraction: tokenUsageFraction,
                estimatedTokenCount: estimatedTokenCount
            )
            .padding(.bottom, 8)
        }
    }
}

struct TokenUsageRingView: View {
    let usageFraction: Double
    let estimatedTokenCount: Int

    private let size: CGFloat = 92

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: max(usageFraction, 0.01))
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 105.0 / 255.0, green: 45.0 / 255.0, blue: 230.0 / 255.0),
                                Color(red: 191.0 / 255.0, green: 54.0 / 255.0, blue: 201.0 / 255.0),
                                Color(red: 105.0 / 255.0, green: 45.0 / 255.0, blue: 230.0 / 255.0)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(Int((usageFraction * 100).rounded()))%")
                        .font(AppTheme.headingFont(17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("usage")
                        .font(AppTheme.uiFont(9, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(width: size, height: size)

            Text(tokenLabel)
                .font(AppTheme.monoFont(11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(width: 108)
    }

    private var tokenLabel: String {
        if estimatedTokenCount >= 1_000 {
            return String(format: "%.1fK / 1M", Double(estimatedTokenCount) / 1_000.0)
        }
        return "\(estimatedTokenCount) / 1M"
    }
}

struct RotatingEarthView: View {
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.blue500.opacity(0.12))
                .blur(radius: 34)
                .frame(width: 164, height: 164)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.navy700,
                            AppTheme.navy900
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
                .overlay {
                    Circle()
                        .strokeBorder(AppTheme.borderStrong, lineWidth: 1)
                }
                .overlay {
                    Circle()
                        .strokeBorder(AppTheme.blue500.opacity(0.22), lineWidth: 8)
                        .blur(radius: 8)
                }
                .shadow(color: AppTheme.blue500.opacity(0.38), radius: 42)
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
                            AppTheme.blue500,
                            AppTheme.navy700,
                            AppTheme.navy900,
                            AppTheme.blue500
                        ],
                        center: .center
                    )
                )

            GlobeGrid()
                .stroke(AppTheme.borderStrong.opacity(0.7), lineWidth: 0.8)

            EarthContinentShape()
                .fill(AppTheme.ice100.opacity(0.92))
                .blur(radius: 0.4)
                .offset(x: -10, y: -2)

            EarthContinentShape()
                .fill(AppTheme.ice100.opacity(0.62))
                .scaleEffect(x: 0.62, y: 0.52)
                .offset(x: 24, y: 18)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.ice100.opacity(0.30), Color.clear],
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
