import Foundation

/// Formats cent amounts into display strings with currency code.
/// Used across all three apps for consistent amount display.
public struct CurrencyFormatter: Sendable {
    public let currencyCode: String

    public init(currencyCode: String = "USD") {
        self.currencyCode = currencyCode
    }

    /// Formats cents into "CODE 1,234.56" with sign prefix for negatives.
    public func format(_ cents: Int64) -> String {
        let value = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "0.00"
        let sign = cents < 0 ? "-" : ""
        return "\(sign)\(currencyCode) \(formatted)"
    }

    /// Formats optional cents, returning "—" for nil.
    public func formatOptional(_ cents: Int64?) -> String {
        guard let cents else { return "—" }
        return format(cents)
    }

    /// Formats a Date into a medium-style date string.
    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
