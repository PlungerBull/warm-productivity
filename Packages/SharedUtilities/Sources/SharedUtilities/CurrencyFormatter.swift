import Foundation

/// Formats cent amounts into display strings with currency symbol.
/// Used across all three apps for consistent amount display.
public struct CurrencyFormatter: Sendable {
    public let currencyCode: String

    public init(currencyCode: String = "USD") {
        self.currencyCode = currencyCode
    }

    /// Formats cents into "$1,234.56" using the locale's currency symbol.
    /// Always uses the absolute value — caller controls sign display.
    public func format(_ cents: Int64) -> String {
        let value = Double(abs(cents)) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    /// Formats cents with an explicit sign prefix: "-$67.32" for expenses, "+$2,320.00" for income.
    public func formatSigned(_ cents: Int64) -> String {
        let base = format(cents)
        if cents < 0 {
            return "-\(base)"
        } else if cents > 0 {
            return "+\(base)"
        }
        return base
    }

    /// Formats optional cents, returning "\u{2014}" for nil.
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
