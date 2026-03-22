import Foundation

/// Result of parsing a quick-add / FAB command string.
/// Used by Expense Tracker (FAB) and To-Do (quick-add).
public struct ParsedCommand: Sendable {
    public var title: String?
    public var amountCents: Int64?
    public var currencyCode: String?
    public var categoryName: String?
    public var accountName: String?
    public var personName: String?
    public var hashtags: [String]
    public var date: Date?

    public init() {
        self.hashtags = []
    }
}

/// Pure Swift parser for FAB/quick-add command strings.
/// No UI, no SwiftData imports. Fully unit-testable.
///
/// Token types:
/// - Amount: `+/-` prefix + number (e.g. "-60", "+25.50", "100"). No sign = positive (income).
/// - @category: Token starting with `@` (e.g. "@Food"). Last wins.
/// - $account: Token starting with `$` (e.g. "$Chase"). Last wins.
/// - /person: Token starting with `/` (e.g. "/John"). Last wins.
/// - #hashtag: Token starting with `#` (e.g. "#work"). Multiple allowed.
/// - Date keywords: "today", "tomorrow", "yesterday" (case-insensitive). Last wins.
/// - Title: All remaining unmatched tokens joined with spaces.
public struct CommandParser: Sendable {
    public init() {}

    public func parse(_ input: String) -> ParsedCommand {
        var command = ParsedCommand()
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return command }

        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // First pass: find the last amount token index so earlier numbers become title text
        var lastAmountIndex: Int?
        for (index, token) in tokens.enumerated() {
            if parseAmount(token) != nil {
                lastAmountIndex = index
            }
        }

        var titleParts: [String] = []

        for (index, token) in tokens.enumerated() {
            if let cents = parseAmount(token), index == lastAmountIndex {
                command.amountCents = cents
            } else if token.hasPrefix("@") && token.count > 1 {
                command.categoryName = String(token.dropFirst())
            } else if token.hasPrefix("$") && token.count > 1 {
                command.accountName = String(token.dropFirst())
            } else if token.hasPrefix("/") && token.count > 1 {
                command.personName = String(token.dropFirst())
            } else if token.hasPrefix("#") && token.count > 1 {
                command.hashtags.append(String(token.dropFirst()))
            } else if let resolved = parseDateKeyword(token) {
                command.date = resolved
            } else {
                titleParts.append(token)
            }
        }

        if !titleParts.isEmpty {
            command.title = titleParts.joined(separator: " ")
        }

        return command
    }

    /// Returns true if the token is a special prefix token (@, $, /, #) or date keyword.
    /// Amounts are NOT included because only the last amount in a command is the actual amount;
    /// earlier numbers should be treated as title text.
    public func isSpecialToken(_ token: String) -> Bool {
        if token.hasPrefix("@") && token.count > 1 { return true }
        if token.hasPrefix("$") && token.count > 1 { return true }
        if token.hasPrefix("/") && token.count > 1 { return true }
        if token.hasPrefix("#") && token.count > 1 { return true }
        if parseDateKeyword(token) != nil { return true }
        return false
    }

    /// Public accessor for amount parsing — used by QuickEntryViewModel
    /// to identify which token is the amount.
    public func parseAmountPublic(_ token: String) -> Int64? {
        parseAmount(token)
    }

    /// Parse a token as an amount in cents.
    /// Accepts: "60", "+60", "-60", "60.50", "-60.50", "+60.50"
    /// Returns nil if the token is not a valid number.
    private func parseAmount(_ token: String) -> Int64? {
        var str = token

        // Check for explicit sign prefix
        var isNegative = false
        if str.hasPrefix("-") {
            isNegative = true
            str = String(str.dropFirst())
        } else if str.hasPrefix("+") {
            str = String(str.dropFirst())
        }

        // Must start with a digit after sign removal
        guard let first = str.first, first.isNumber else { return nil }

        // Validate: only digits and at most one decimal point
        var dotCount = 0
        for char in str {
            if char == "." {
                dotCount += 1
                if dotCount > 1 { return nil }
            } else if !char.isNumber {
                return nil
            }
        }

        guard let value = Double(str) else { return nil }
        let cents = Int64(round(value * 100))

        // No sign = positive (income). Explicit minus = negative (expense).
        return isNegative ? -cents : cents
    }

    /// Resolve date keywords to actual dates.
    private func parseDateKeyword(_ token: String) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch token.lowercased() {
        case "today":
            return today
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: today)
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: today)
        default:
            return nil
        }
    }
}
