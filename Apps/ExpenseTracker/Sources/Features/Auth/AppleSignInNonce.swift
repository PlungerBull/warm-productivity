import Foundation
import CryptoKit

struct AppleSignInNonce {
    let raw: String
    let hashed: String

    /// The most recently generated raw nonce. Read by AuthViewModel after
    /// the Apple credential callback returns. Both write (generate) and
    /// read happen on @MainActor.
    nonisolated(unsafe) static var current: String?

    /// Generate a random nonce, store the raw value in `current`, and
    /// return both raw and SHA-256-hashed versions.
    static func generate() -> AppleSignInNonce {
        let raw = randomNonceString()
        let hashed = sha256(raw)
        current = raw
        return AppleSignInNonce(raw: raw, hashed: hashed)
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(errorCode == errSecSuccess)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
