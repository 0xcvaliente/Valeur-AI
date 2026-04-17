import AppKit
import SwiftUI

enum AppTheme {
    private enum TypefaceStyle {
        case light
        case regular
        case medium
        case bold
    }

    static let navy900 = Color(red: 15.0 / 255.0, green: 40.0 / 255.0, blue: 84.0 / 255.0)
    static let navy700 = Color(red: 28.0 / 255.0, green: 77.0 / 255.0, blue: 141.0 / 255.0)
    static let blue500 = Color(red: 73.0 / 255.0, green: 136.0 / 255.0, blue: 196.0 / 255.0)
    static let ice100 = Color(red: 189.0 / 255.0, green: 232.0 / 255.0, blue: 245.0 / 255.0)

    static let backgroundPrimary = dynamic(
        light: Color.white,
        dark: Color(red: 15.0 / 255.0, green: 40.0 / 255.0, blue: 84.0 / 255.0)
    )
    static let backgroundSecondary = dynamic(
        light: Color(red: 247.0 / 255.0, green: 247.0 / 255.0, blue: 248.0 / 255.0),
        dark: Color(red: 18.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0)
    )
    static let sidebarGrey = dynamic(
        light: Color(red: 245.0 / 255.0, green: 245.0 / 255.0, blue: 247.0 / 255.0),
        dark: Color(red: 17.0 / 255.0, green: 31.0 / 255.0, blue: 57.0 / 255.0)
    )
    static let surfacePrimary = dynamic(
        light: Color.white,
        dark: Color(red: 28.0 / 255.0, green: 77.0 / 255.0, blue: 141.0 / 255.0).opacity(0.22)
    )
    static let surfaceSecondary = dynamic(
        light: Color(red: 243.0 / 255.0, green: 244.0 / 255.0, blue: 246.0 / 255.0),
        dark: Color(red: 28.0 / 255.0, green: 77.0 / 255.0, blue: 141.0 / 255.0).opacity(0.14)
    )
    static let border = dynamic(
        light: Color.black.opacity(0.07),
        dark: blue500.opacity(0.22)
    )
    static let borderStrong = dynamic(
        light: Color.black.opacity(0.10),
        dark: ice100.opacity(0.22)
    )
    static let textPrimary = dynamic(
        light: Color(red: 32.0 / 255.0, green: 33.0 / 255.0, blue: 36.0 / 255.0),
        dark: ice100
    )
    static let textSecondary = dynamic(
        light: Color(red: 111.0 / 255.0, green: 111.0 / 255.0, blue: 115.0 / 255.0),
        dark: ice100.opacity(0.66)
    )
    static let logoColor = dynamic(
        light: navy700,
        dark: Color.white
    )
    static let accent = blue500
    static let accentStrong = navy700

    static let radius: CGFloat = 12

    static func uiFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = scaled(size)
        return customFont(size: scaledSize, style: typefaceStyle(for: weight)) ?? .system(size: scaledSize, weight: weight)
    }

    static func headingFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let scaledSize = scaled(size)
        return customFont(size: scaledSize, style: typefaceStyle(for: weight)) ?? .system(size: scaledSize, weight: weight)
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = scaled(size)
        return customFont(size: scaledSize, style: typefaceStyle(for: weight)) ?? .system(size: scaledSize, weight: weight)
    }

    static func codeFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .monospaced)
    }

    static func uiNSFont(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let scaledSize = scaled(size)
        if let name = installedFontName(for: typefaceStyle(for: weight)),
           let font = NSFont(name: name, size: scaledSize) {
            return font
        }
        return NSFont.systemFont(ofSize: scaledSize, weight: weight)
    }

    private static func dynamic(light: Color, dark: Color) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
                case .darkAqua:
                    return NSColor(dark)
                default:
                    return NSColor(light)
                }
            }
        )
    }

    private static func customFont(size: CGFloat, style: TypefaceStyle) -> Font? {
        guard let name = installedFontName(for: style) else { return nil }
        return .custom(name, size: size)
    }

    private static func scaled(_ size: CGFloat) -> CGFloat {
        size * currentFontSize.scale
    }

    private static var currentFontSize: AppFontSize {
        AppFontSize(rawValue: UserDefaults.standard.string(forKey: AppFontSize.defaultsKey) ?? "") ?? .normal
    }

    private static func installedFontName(for style: TypefaceStyle) -> String? {
        nexaCandidates[style]?.first(where: { NSFont(name: $0, size: 12) != nil })
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
