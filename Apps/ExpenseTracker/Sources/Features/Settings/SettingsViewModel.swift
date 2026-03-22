import Foundation
import SharedModels

@MainActor
@Observable
final class SettingsViewModel {
    private let userSettingsRepository: UserSettingsRepository
    private let userRepository: UserRepository
    private let currencyRepository: CurrencyRepository
    let userId: UUID

    var user: User?
    var settings: UserSettings?
    var currencies: [GlobalCurrency] = []
    var appVersion: String
    var errorMessage: String?

    // Sidebar layout bindings
    var showBankAccounts: Bool = true
    var showCategories: Bool = true
    var showPeople: Bool = true

    init(
        userSettingsRepository: UserSettingsRepository,
        userRepository: UserRepository,
        currencyRepository: CurrencyRepository,
        userId: UUID
    ) {
        self.userSettingsRepository = userSettingsRepository
        self.userRepository = userRepository
        self.currencyRepository = currencyRepository
        self.userId = userId
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    func loadSettings() {
        do {
            user = try userRepository.fetchUser(id: userId)
            settings = try userSettingsRepository.fetchSettings(userId: userId)
            currencies = try currencyRepository.fetchAll()

            showBankAccounts = settings?.sidebarShowBankAccounts ?? true
            showCategories = settings?.sidebarShowCategories ?? true
            showPeople = settings?.sidebarShowPeople ?? true
        } catch {
            errorMessage = "Failed to load settings: \(error.localizedDescription)"
        }
    }

    func updateTheme(_ theme: String) {
        do {
            try userSettingsRepository.updateTheme(userId: userId, theme: theme)
            settings?.theme = theme
        } catch {
            errorMessage = "Failed to update theme: \(error.localizedDescription)"
        }
    }

    func updateCurrency(_ code: String) {
        do {
            try userSettingsRepository.updateMainCurrency(userId: userId, currency: code)
            settings?.mainCurrency = code
        } catch {
            errorMessage = "Failed to update currency: \(error.localizedDescription)"
        }
    }

    func saveSidebarLayout() {
        do {
            try userSettingsRepository.updateSettings(userId: userId) { settings in
                settings.sidebarShowBankAccounts = self.showBankAccounts
                settings.sidebarShowCategories = self.showCategories
                settings.sidebarShowPeople = self.showPeople
            }
        } catch {
            errorMessage = "Failed to save sidebar layout: \(error.localizedDescription)"
        }
    }
}
