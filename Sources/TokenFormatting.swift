import Foundation

enum TokenFormatting {
    static func estimatedTokenCount(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let words = trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let punctuation = trimmed.unicodeScalars.reduce(into: 0) { total, scalar in
            if CharacterSet.punctuationCharacters.contains(scalar) {
                total += 1
            }
        }

        let estimated = (Double(words) * 1.33) + (Double(punctuation) * 0.15)
        return max(Int(ceil(estimated)), 1)
    }

    private static let compactFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return formatter
    }()

    static func compactCount(_ count: Int) -> String {
        let value = max(count, 0)
        switch value {
        case 1_000_000...:
            return format(Double(value) / 1_000_000.0, suffix: "M")
        case 1_000...:
            return format(Double(value) / 1_000.0, suffix: "K")
        default:
            return "\(value)"
        }
    }

    static func windowLabel(_ count: Int) -> String {
        "\(compactCount(count)) tokens"
    }

    static func percentLabel(for fraction: Double) -> String {
        percentFormatter.string(from: NSNumber(value: max(fraction, 0))) ?? "\(Int((max(fraction, 0) * 100).rounded()))%"
    }

    private static func format(_ value: Double, suffix: String) -> String {
        let number = NSNumber(value: value)
        let rounded = compactFormatter.string(from: number) ?? String(format: "%.2f", value)
        return "\(rounded)\(suffix)"
    }
}
