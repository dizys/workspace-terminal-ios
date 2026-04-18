import CryptoKit
import Foundation

/// PKCE (Proof Key for Code Exchange, RFC 7636) helper.
///
/// Generates a fresh `(verifier, challenge)` pair per OIDC flow. The verifier
/// is held in memory until the redirect lands; the challenge is sent to the
/// authorization endpoint.
public struct PKCEPair: Sendable, Hashable {
    public let verifier: String
    public let challenge: String
    public let challengeMethod: String

    public static let s256Method = "S256"
}

public enum PKCE {
    /// Generate a fresh PKCE pair using SHA-256.
    public static func generate(verifierLength: Int = 64) -> PKCEPair {
        precondition(verifierLength >= 43 && verifierLength <= 128, "RFC 7636 §4.1: 43..128")
        let verifier = randomURLSafeString(length: verifierLength)
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(hashed).base64URLEncodedString()
        return PKCEPair(verifier: verifier, challenge: challenge, challengeMethod: PKCEPair.s256Method)
    }

    /// Generate the random verifier string from the URL-safe alphabet.
    static func randomURLSafeString(length: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }
}

extension Data {
    /// Standard base64 → URL-safe variant (RFC 7515 §2): + → -, / → _, no padding.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
