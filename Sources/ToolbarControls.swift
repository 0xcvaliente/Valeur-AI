import SwiftUI

struct ToolbarIconLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(AppTheme.uiFont(15, weight: .semibold))
            .frame(width: 22, height: 18)
    }
}



struct ToolbarTransparentPillChrome: ViewModifier {
    var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Capsule())
            .scaleEffect(isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

struct ToolbarTransparentCircleChrome: ViewModifier {
    var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .frame(width: 30, height: 30)
            .contentShape(Circle())
            .scaleEffect(isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

// MARK: - Transparent Button Styles

struct ToolbarTransparentCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(ToolbarTransparentCircleChrome(isPressed: configuration.isPressed))
    }
}

struct ToolbarTransparentPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(ToolbarTransparentPillChrome(isPressed: configuration.isPressed))
    }
}

// MARK: - Toolbar Labels

struct ToolbarChipLabel: View {
    let title: String
    var systemName: String? = nil
    var trailingSystemName: String? = nil
    var foregroundColor: Color = AppTheme.textPrimary

    private let leadingIconWidth: CGFloat = 12
    private let trailingIconWidth: CGFloat = 10

    var body: some View {
        HStack(spacing: 6) {
            if let systemName {
                Image(systemName: systemName)
                    .font(AppTheme.uiFont(12, weight: .semibold))
                    .frame(width: leadingIconWidth)
            }

            Text(title)
                .font(AppTheme.uiFont(12, weight: .semibold))
                .lineLimit(1)

            if let trailingSystemName {
                Image(systemName: trailingSystemName)
                    .font(AppTheme.uiFont(10, weight: .semibold))
                    .frame(width: trailingIconWidth)
            }
        }
        .foregroundStyle(foregroundColor)
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Convenience Extensions

extension View {
    func toolbarTransparentPillChrome(isPressed: Bool = false) -> some View {
        modifier(ToolbarTransparentPillChrome(isPressed: isPressed))
    }

    func toolbarTransparentCircleChrome(isPressed: Bool = false) -> some View {
        modifier(ToolbarTransparentCircleChrome(isPressed: isPressed))
    }
}

// MARK: - Cluster Icon

struct ClusterIcon: View {
    let systemName: String
    var isActive: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(AppTheme.uiFont(15, weight: .semibold))
            .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textPrimary)
            .frame(width: 22, height: 18)
            .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

struct TransparentTitlebarRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 18) {
                content
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: AppTheme.titlebarBackdropHeight, alignment: .center)
        .padding(.horizontal, AppTheme.titlebarContentInset)
        .background(Color.clear)
    }
}
