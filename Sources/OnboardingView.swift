import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var selectedStep = 0

    private static let steps = [
        OnboardingStep(
            title: "Private by default",
            subtitle: "Your chats and workspaces stay on this Mac.",
            systemImage: "lock.shield",
            detail: "Valeur AI stores conversation and workspace data locally, encrypts message content at rest, and keeps provider API keys in macOS Keychain.",
            highlights: [
                "Local-first storage",
                "Encrypted message history",
                "Keychain-protected API keys"
            ]
        ),
        OnboardingStep(
            title: "Bring your own models",
            subtitle: "Connect the AI providers you already use.",
            systemImage: "key.horizontal",
            detail: "Add API keys in Settings, choose default models per provider, and switch models from the composer when a task needs something different.",
            highlights: [
                "OpenAI, Anthropic, Gemini, and OpenRouter",
                "Per-provider model defaults",
                "Fast model switching while you work"
            ]
        ),
        OnboardingStep(
            title: "Chat and workspace",
            subtitle: "Move between conversations and structured writing.",
            systemImage: "rectangle.3.group.bubble.left",
            detail: "Use chat for quick questions, then open the workspace when you need editable blocks, revisions, imports, and exports.",
            highlights: [
                "Chat sidebar for conversation history",
                "Workspace blocks with AI revision tools",
                "Import and export when work is ready"
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                stepList
                Divider()
                stepDetail
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
        }
        .frame(width: 760, height: 540)
        .background(AppTheme.backgroundPrimary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.root")
    }

    private var header: some View {
        HStack(spacing: 16) {
            ValeurLogoMark(size: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text("Welcome to Valeur AI")
                    .font(AppTheme.headingFont(22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityIdentifier("onboarding.title")

                Text("A short setup tour before you start.")
                    .font(AppTheme.uiFont(13))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Self.steps.indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedStep = index
                    }
                } label: {
                    OnboardingStepRow(
                        step: Self.steps[index],
                        number: index + 1,
                        isSelected: selectedStep == index
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.step.\(index)")
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 256)
        .frame(maxHeight: .infinity)
        .background(AppTheme.surfaceSecondary.opacity(0.45))
    }

    private var stepDetail: some View {
        let step = Self.steps[selectedStep]

        return VStack(alignment: .leading, spacing: 22) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.13))
                    .frame(width: 86, height: 86)

                Image(systemName: step.systemImage)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(AppTheme.accentStrong)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(step.title)
                    .font(AppTheme.headingFont(28, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                Text(step.detail)
                    .font(AppTheme.uiFont(14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(step.highlights, id: \.self) { highlight in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.accentStrong)
                            .frame(width: 16)

                        Text(highlight)
                            .font(AppTheme.uiFont(13))
                            .foregroundStyle(AppTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer()
        }
        .padding(34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.backgroundPrimary)
        .id(selectedStep)
        .transition(.opacity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Skip Tour") {
                onComplete()
            }
            .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true, showBorder: true))
            .accessibilityIdentifier("onboarding.skipButton")

            Spacer()

            Text("\(selectedStep + 1) of \(Self.steps.count)")
                .font(AppTheme.uiFont(12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .monospacedDigit()

            Button(previousButtonTitle) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedStep = max(0, selectedStep - 1)
                }
            }
            .buttonStyle(AppChromeButtonStyle(tone: .secondary, compact: true, showBorder: true))
            .disabled(selectedStep == 0)
            .accessibilityIdentifier("onboarding.backButton")

            Button(primaryButtonTitle) {
                if selectedStep == Self.steps.count - 1 {
                    onComplete()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedStep += 1
                    }
                }
            }
            .buttonStyle(AppChromeButtonStyle(tone: .accent, compact: true))
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("onboarding.primaryButton")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppTheme.backgroundPrimary)
    }

    private var previousButtonTitle: String {
        selectedStep == 0 ? "Back" : "Previous"
    }

    private var primaryButtonTitle: String {
        selectedStep == Self.steps.count - 1 ? "Start Using Valeur AI" : "Next"
    }
}

private struct OnboardingStep: Equatable {
    let title: String
    let subtitle: String
    let systemImage: String
    let detail: String
    let highlights: [String]
}

private struct OnboardingStepRow: View {
    let step: OnboardingStep
    let number: Int
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected ? AppTheme.accent : AppTheme.surfacePrimary)
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(AppTheme.uiFont(12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : AppTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(AppTheme.uiFont(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(step.subtitle)
                    .font(AppTheme.uiFont(12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(isSelected ? AppTheme.surfacePrimary : Color.clear)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .strokeBorder(isSelected ? AppTheme.borderStrong : Color.clear, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
    }
}
