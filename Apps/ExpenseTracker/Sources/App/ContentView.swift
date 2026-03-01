import SwiftUI
import SharedUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: WPSpacing.lg) {
                EmptyStateView(
                    icon: "dollarsign.circle",
                    title: "Expense Tracker",
                    message: "Scaffolding complete. Phase 1 UI coming soon."
                )
            }
            .navigationTitle("Expense Tracker")
        }
    }
}

#Preview {
    ContentView()
}
