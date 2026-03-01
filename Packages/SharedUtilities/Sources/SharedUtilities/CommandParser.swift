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
/// Placeholder — full implementation during Phase 1.
public struct CommandParser: Sendable {
    public init() {}

    public func parse(_ input: String) -> ParsedCommand {
        // Placeholder — returns empty command
        var command = ParsedCommand()
        command.title = input.isEmpty ? nil : input
        return command
    }
}
