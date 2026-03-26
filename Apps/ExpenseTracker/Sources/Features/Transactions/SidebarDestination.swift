import Foundation

enum SidebarDestination: Hashable {
    case inbox
    case ledger
    case bankAccount(id: UUID, name: String)
    case category(id: UUID, name: String)
    case hashtag(id: UUID, name: String)

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .ledger: "Ledger"
        case .bankAccount(_, let name): name
        case .category(_, let name): name
        case .hashtag(_, let name): name
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
