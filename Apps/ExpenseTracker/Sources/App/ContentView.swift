import SwiftUI
import SwiftData
import SharedUI
import SharedModels

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: AuthViewModel?

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.authState {
                case .loading:
                    LoadingView(message: "Loading...")
                case .signedOut:
                    AuthView(viewModel: viewModel)
                case .needsSetup(let userId):
                    OnboardingView(
                        viewModel: OnboardingViewModel(
                            userId: userId,
                            userSettingsRepository: UserSettingsRepository(modelContext: modelContext),
                            bankAccountRepository: BankAccountRepository(modelContext: modelContext),
                            categoryRepository: CategoryRepository(modelContext: modelContext),
                            transactionRepository: TransactionRepository(modelContext: modelContext),
                            currencyRepository: CurrencyRepository(modelContext: modelContext),
                            noteEntryRepository: NoteEntryRepository(modelContext: modelContext),
                            entityLinkRepository: EntityLinkRepository(modelContext: modelContext),
                            currencySyncService: CurrencySyncService(modelContext: modelContext)
                        ),
                        onSetupComplete: {
                            viewModel.authState = .signedIn(userId: userId)
                        }
                    )
                case .signedIn(let userId):
                    MainTabView(
                        userId: userId,
                        onSignOut: { await viewModel.signOut() }
                    )
                }
            } else {
                LoadingView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wpGroupedBackground.ignoresSafeArea(.all))
        .task {
            let userRepo = UserRepository(modelContext: modelContext)
            let accountRepo = BankAccountRepository(modelContext: modelContext)
            let vm = AuthViewModel(
                userRepository: userRepo,
                bankAccountRepository: accountRepo
            )
            viewModel = vm
            await vm.checkSession()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: User.self, inMemory: true)
}
