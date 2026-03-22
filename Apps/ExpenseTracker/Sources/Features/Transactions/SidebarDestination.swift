import Foundation

enum SidebarDestination: Hashable {
    case inbox
    case ledger
    case bankAccount(id: UUID)
    case category(id: UUID)
    case hashtag(id: UUID)

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .ledger: "Ledger"
        case .bankAccount: "Account"
        case .category: "Category"
        case .hashtag: "Hashtag"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "tray.fill"
        case .ledger: "list.bullet"
        case .bankAccount: "building.columns"
        case .category: "folder"
        case .hashtag: "number"
        }
    }
}
