import Foundation

/// Errors for local enforcement of database constraints (offline-first).
enum ConstraintError: LocalizedError {
    case duplicate(String)
    case foreignKeyViolation(String)
    case checkViolation(String)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .duplicate(let message): message
        case .foreignKeyViolation(let message): message
        case .checkViolation(let message): message
        case .invalidValue(let message): message
        }
    }
}
