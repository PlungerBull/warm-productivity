import Foundation
import SwiftData

@Model
public final class UserSettings {
    @Attribute(.unique) public var userId: UUID
    public var theme: String
    public var startOfWeek: Int
    public var mainCurrency: String
    public var transactionSortPreference: String
    public var budgetEnabled: Bool
    public var linkedNotesVisibleInNotesApp: Bool
    public var sidebarShowBankAccounts: Bool
    public var sidebarShowPeople: Bool
    public var sidebarShowCategories: Bool
    public var displayTimezone: String
    public var todoTabShowInbox: Bool
    public var todoTabShowToday: Bool
    public var todoTabShowUpcoming: Bool
    public var todoTabShowBrowse: Bool
    public var expenseTabShowBudgeting: Bool
    public var expenseTabShowReconciliations: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        userId: UUID = UUID(),
        theme: String = "system",
        startOfWeek: Int = 0,
        mainCurrency: String = "USD",
        transactionSortPreference: String = "date",
        budgetEnabled: Bool = false,
        linkedNotesVisibleInNotesApp: Bool = true,
        sidebarShowBankAccounts: Bool = true,
        sidebarShowPeople: Bool = true,
        sidebarShowCategories: Bool = true,
        displayTimezone: String = "UTC",
        todoTabShowInbox: Bool = true,
        todoTabShowToday: Bool = true,
        todoTabShowUpcoming: Bool = true,
        todoTabShowBrowse: Bool = true,
        expenseTabShowBudgeting: Bool = true,
        expenseTabShowReconciliations: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.theme = theme
        self.startOfWeek = startOfWeek
        self.mainCurrency = mainCurrency
        self.transactionSortPreference = transactionSortPreference
        self.budgetEnabled = budgetEnabled
        self.linkedNotesVisibleInNotesApp = linkedNotesVisibleInNotesApp
        self.sidebarShowBankAccounts = sidebarShowBankAccounts
        self.sidebarShowPeople = sidebarShowPeople
        self.sidebarShowCategories = sidebarShowCategories
        self.displayTimezone = displayTimezone
        self.todoTabShowInbox = todoTabShowInbox
        self.todoTabShowToday = todoTabShowToday
        self.todoTabShowUpcoming = todoTabShowUpcoming
        self.todoTabShowBrowse = todoTabShowBrowse
        self.expenseTabShowBudgeting = expenseTabShowBudgeting
        self.expenseTabShowReconciliations = expenseTabShowReconciliations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
