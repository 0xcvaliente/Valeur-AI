import AppKit
import SwiftUI

enum AppTheme {
    private enum TypefaceStyle {
        case light
        case regular
        case medium
        case bold
    }

    // Orange accent — matched to logo
    static let orange400 = Color(red: 248.0 / 255.0, green: 148.0 / 255.0, blue: 96.0 / 255.0)
    static let orange500 = Color(red: 241.0 / 255.0, green: 112.0 / 255.0, blue: 52.0 / 255.0)
    static let orange600 = Color(red: 208.0 / 255.0, green: 82.0 / 255.0, blue: 24.0 / 255.0)
    static let orange700 = Color(red: 162.0 / 255.0, green: 56.0 / 255.0, blue: 10.0 / 255.0)

    // Blue accent
    static let blue400 = Color(red: 96.0 / 255.0, green: 165.0 / 255.0, blue: 250.0 / 255.0)
    static let blue500 = Color(red: 59.0 / 255.0, green: 130.0 / 255.0, blue: 246.0 / 255.0)
    static let blue600 = Color(red: 37.0 / 255.0, green: 99.0 / 255.0, blue: 235.0 / 255.0)
    static let blue700 = Color(red: 29.0 / 255.0, green: 78.0 / 255.0, blue: 216.0 / 255.0)

    private static let chromeLight = nsColor(red: 250, green: 250, blue: 250)
    private static let chromeDark = nsColor(red: 14, green: 14, blue: 14)
    private static let chromeElevatedLight = nsColor(red: 255, green: 255, blue: 255)
    private static let chromeElevatedDark = nsColor(red: 36, green: 36, blue: 36)
    private static let chromeAccentLight = nsColor(red: 240, green: 240, blue: 240, alpha: 0.80)
    private static let chromeAccentDark = nsColor(red: 255, green: 255, blue: 255, alpha: 0.04)
    private static let backgroundPrimaryLight = nsColor(red: 247, green: 247, blue: 247)
    private static let backgroundPrimaryDark = nsColor(red: 17, green: 17, blue: 17)
    private static let backgroundSecondaryLight = nsColor(red: 238, green: 238, blue: 238)
    private static let backgroundSecondaryDark = nsColor(red: 24, green: 24, blue: 24)
    private static let sidebarLight = nsColor(red: 240, green: 240, blue: 240)
    private static let sidebarDark = nsColor(red: 22, green: 22, blue: 22)
    private static let surfacePrimaryLight = nsColor(red: 255, green: 255, blue: 255)
    private static let surfacePrimaryDark = nsColor(red: 30, green: 30, blue: 30)
    private static let surfaceSecondaryLight = nsColor(red: 243, green: 243, blue: 243)
    private static let surfaceSecondaryDark = nsColor(red: 38, green: 38, blue: 38)
    private static let borderLight = nsColor(red: 0, green: 0, blue: 0, alpha: 0.09)
    private static let borderDark = nsColor(red: 255, green: 255, blue: 255, alpha: 0.10)
    private static let borderStrongLight = nsColor(red: 0, green: 0, blue: 0, alpha: 0.17)
    private static let borderStrongDark = nsColor(red: 255, green: 255, blue: 255, alpha: 0.18)
    private static let textPrimaryLight = nsColor(red: 17, green: 17, blue: 17)
    private static let textPrimaryDark = nsColor(red: 238, green: 238, blue: 238)
    private static let textSecondaryLight = nsColor(red: 107, green: 107, blue: 107)
    private static let textSecondaryDark = nsColor(red: 136, green: 136, blue: 136)

    static let windowChromeBackground = dynamic(
        light: Color(nsColor: chromeLight),
        dark: Color(nsColor: chromeDark)
    )
    static let backgroundPrimary = dynamic(
        light: Color(nsColor: backgroundPrimaryLight),
        dark: Color(nsColor: backgroundPrimaryDark)
    )
    static let backgroundSecondary = dynamic(
        light: Color(nsColor: backgroundSecondaryLight),
        dark: Color(nsColor: backgroundSecondaryDark)
    )
    static let chromeElevated = dynamic(
        light: Color(nsColor: chromeElevatedLight),
        dark: Color(nsColor: chromeElevatedDark)
    )
    static let chromeAccent = dynamic(
        light: Color(nsColor: chromeAccentLight),
        dark: Color(nsColor: chromeAccentDark)
    )
    static let sidebarGrey = dynamic(
        light: Color(nsColor: sidebarLight),
        dark: Color(nsColor: sidebarDark)
    )
    static let surfacePrimary = dynamic(
        light: Color(nsColor: surfacePrimaryLight),
        dark: Color(nsColor: surfacePrimaryDark)
    )
    static let surfaceSecondary = dynamic(
        light: Color(nsColor: surfaceSecondaryLight),
        dark: Color(nsColor: surfaceSecondaryDark)
    )
    static let border = dynamic(
        light: Color(nsColor: borderLight),
        dark: Color(nsColor: borderDark)
    )
    static let borderStrong = dynamic(
        light: Color(nsColor: borderStrongLight),
        dark: Color(nsColor: borderStrongDark)
    )
    static let textPrimary = dynamic(
        light: Color(nsColor: textPrimaryLight),
        dark: Color(nsColor: textPrimaryDark)
    )
    static let textSecondary = dynamic(
        light: Color(nsColor: textSecondaryLight),
        dark: Color(nsColor: textSecondaryDark)
    )
    static let logoColor = dynamic(
        light: orange600,
        dark: orange400
    )
    static var accent: Color { AppAppearance.current.usesBlueAccent ? blue500 : orange500 }
    static var accentDark: Color { AppAppearance.current.usesBlueAccent ? blue600 : orange600 }
    static var accentBorder: Color { AppAppearance.current.usesBlueAccent ? blue700 : orange700 }
    static var accentLight: Color { AppAppearance.current.usesBlueAccent ? blue400 : orange400 }
    static var accentStrong: Color {
        AppAppearance.current.usesBlueAccent
            ? dynamic(light: blue600, dark: blue400)
            : dynamic(light: orange600, dark: orange400)
    }
    static let windowChromeNSColor = dynamicNSColor(
        light: chromeLight,
        dark: chromeDark
    )

    static let radius: CGFloat = 12
    static let controlRadius: CGFloat = 10
    static let contentHorizontalPadding: CGFloat = 144
    static let contentTopPadding: CGFloat = 16
    static let contentBottomPadding: CGFloat = 36
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 12
    static let panelPadding: CGFloat = 28
    static let titlebarBackdropHeight: CGFloat = 64
    static let titlebarContentInset: CGFloat = 32
    static let systemFontFamilyName = "System"
    static let nexaFontFamilyName = "Nexa"

    static func uiFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = scaled(size)
        if let font = resolvedNSFont(size: scaledSize, style: typefaceStyle(for: weight)) {
            return Font(font)
        }
        return .system(size: scaledSize, weight: weight)
    }

    static func headingFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let scaledSize = scaled(size)
        if let font = resolvedNSFont(size: scaledSize, style: typefaceStyle(for: weight)) {
            return Font(font)
        }
        return .system(size: scaledSize, weight: weight)
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .monospaced)
    }

    static func codeFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .monospaced)
    }

    static func uiNSFont(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let scaledSize = scaled(size)
        if let font = resolvedNSFont(size: scaledSize, style: typefaceStyle(for: weight)) {
            return font
        }
        return NSFont.systemFont(ofSize: scaledSize, weight: weight)
    }

    private static func dynamic(light: Color, dark: Color) -> Color {
        Color(
            nsColor: dynamicNSColor(
                light: NSColor(light),
                dark: NSColor(dark)
            )
        )
    }

    private static func dynamicNSColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua:
                return dark
            default:
                return light
            }
        }
    }

    private static func nsColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) -> NSColor {
        NSColor(
            srgbRed: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0,
            alpha: alpha
        )
    }

    private static func scaled(_ size: CGFloat) -> CGFloat {
        size * currentFontSize.scale
    }

    private static var currentFontSize: AppFontSize {
        AppFontSize(rawValue: UserDefaults.standard.string(forKey: AppFontSize.defaultsKey) ?? "") ?? .normal
    }

    private static var currentFontFamilyName: String {
        let storedValue = UserDefaults.standard.string(forKey: "settings.appFontFamily")
        return SettingsStore.normalizeFontFamilyName(storedValue)
    }

    static func installedFontFamilyNames() -> [String] {
        NSFontManager.shared.availableFontFamilies
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func fontFamilyOptions() -> [String] {
        let installed = installedFontFamilyNames().filter {
            $0.caseInsensitiveCompare(systemFontFamilyName) != .orderedSame &&
            $0.caseInsensitiveCompare(nexaFontFamilyName) != .orderedSame
        }
        return [systemFontFamilyName, nexaFontFamilyName] + installed
    }

    private static func resolvedNSFont(size: CGFloat, style: TypefaceStyle) -> NSFont? {
        let familyName = currentFontFamilyName
        if familyName.caseInsensitiveCompare(systemFontFamilyName) == .orderedSame {
            return nil
        }

        if familyName.caseInsensitiveCompare(nexaFontFamilyName) == .orderedSame {
            guard let name = nexaCandidates[style]?.first(where: { NSFont(name: $0, size: 12) != nil }) else {
                return nil
            }
            return NSFont(name: name, size: size)
        }

        guard let base = NSFont(name: familyName, size: size) else { return nil }
        switch style {
        case .bold:
            return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        default:
            return base
        }
    }

    private static func typefaceStyle(for weight: Font.Weight) -> TypefaceStyle {
        switch weight {
        case .ultraLight, .thin, .light:
            return .light
        case .medium:
            return .medium
        case .semibold, .bold, .heavy, .black:
            return .bold
        default:
            return .regular
        }
    }

    private static func typefaceStyle(for weight: NSFont.Weight) -> TypefaceStyle {
        if weight >= .semibold {
            return .bold
        }
        if weight >= .medium {
            return .medium
        }
        if weight <= .light {
            return .light
        }
        return .regular
    }

    private static let nexaCandidates: [TypefaceStyle: [String]] = [
        .light: [
            "NexaLight",
            "Nexa-Light",
            "Nexa Light"
        ],
        .regular: [
            "NexaRegular",
            "Nexa-Regular",
            "Nexa Book",
            "NexaBook"
        ],
        .medium: [
            "NexaRegular",
            "Nexa-Regular",
            "NexaBook",
            "Nexa Book"
        ],
        .bold: [
            "NexaBold",
            "Nexa-Bold",
            "Nexa Bold",
            "NexaHeavy",
            "Nexa-Heavy",
            "Nexa Heavy"
        ]
    ]
}

enum AppButtonTone {
    case accent
    case secondary
    case destructive
}

struct AppChromeButtonStyle: ButtonStyle {
    let tone: AppButtonTone
    let compact: Bool
    let showBorder: Bool
    let tight: Bool
    let showBackground: Bool

    init(tone: AppButtonTone = .secondary, compact: Bool = false, showBorder: Bool = false, tight: Bool = false, showBackground: Bool = true) {
        self.tone = tone
        self.compact = compact
        self.showBorder = showBorder
        self.tight = tight
        self.showBackground = showBackground
    }

    func makeBody(configuration: Configuration) -> some View {
        let radius = compact ? AppTheme.controlRadius : AppTheme.radius
        configuration.label
            .font(AppTheme.uiFont(compact ? 13 : 14, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, tight ? 12 : (compact ? 12 : 14))
            .padding(.vertical, tight ? 8 : (compact ? 7 : 9))
            .background(showBackground ? AnyShapeStyle(background(configuration.isPressed)) : AnyShapeStyle(Color.clear))
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(borderColor(configuration.isPressed), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch tone {
        case .accent:
            return Color.white
        case .secondary:
            return AppTheme.textPrimary
        case .destructive:
            return Color.white
        }
    }

    private func background(_ isPressed: Bool) -> some ShapeStyle {
        switch tone {
        case .accent:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        AppTheme.accentDark.opacity(isPressed ? 0.92 : 1.0),
                        AppTheme.accent.opacity(isPressed ? 0.92 : 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            return AnyShapeStyle(isPressed ? AppTheme.surfacePrimary : AppTheme.surfaceSecondary)
        case .destructive:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.red.opacity(isPressed ? 0.78 : 0.88),
                        Color(red: 0.72, green: 0.20, blue: 0.16).opacity(isPressed ? 0.78 : 0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func borderColor(_ isPressed: Bool) -> Color {
        switch tone {
        case .accent:
            return AppTheme.accentBorder.opacity(isPressed ? 0.65 : 0.78)
        case .secondary:
            return AppTheme.border
        case .destructive:
            return Color.red.opacity(isPressed ? 0.45 : 0.6)
        }
    }
}
