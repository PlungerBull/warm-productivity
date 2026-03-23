import Foundation

/// Formats cent amounts into display strings with 3-letter currency code.
/// Uses code (e.g. "USD", "PEN") instead of symbol to avoid ambiguity.
/// Used across all three apps for consistent amount display.
public struct CurrencyFormatter: Sendable {
    public let currencyCode: String

    public init(currencyCode: String = "USD") {
        self.currencyCode = currencyCode
    }

    /// Formats cents into a plain decimal string: "1,234.56".
    /// Always uses the absolute value — caller controls sign display.
    private func formatDecimal(_ cents: Int64) -> String {
        let value = Double(abs(cents)) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    /// Formats cents with currency code: "USD1,234.56".
    /// Always uses the absolute value — caller controls sign display.
    public func format(_ cents: Int64) -> String {
        "\(currencyCode)\(formatDecimal(cents))"
    }

    /// Formats cents with sign and 3-letter currency code: "-USD67.32" for expenses, "+USD2,320.00" for income.
    public func formatSigned(_ cents: Int64) -> String {
        let base = formatDecimal(cents)
        if cents < 0 {
            return "-\(currencyCode)\(base)"
        } else if cents > 0 {
            return "+\(currencyCode)\(base)"
        }
        return "\(currencyCode)\(base)"
    }

    /// Formats optional cents with currency code, returning "\u{2014}" for nil.
    public func formatOptional(_ cents: Int64?) -> String {
        guard let cents else { return "\u{2014}" }
        return format(cents)
    }

    /// Formats optional cents with sign prefix, returning "\u{2014}" for nil.
    public func formatOptionalSigned(_ cents: Int64?) -> String {
        guard let cents else { return "\u{2014}" }
        return formatSigned(cents)
    }

    /// Formats a Date into a medium-style date string.
    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
