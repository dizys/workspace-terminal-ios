import CryptoKit
import Foundation
import Testing
@testable import Auth

@Suite("PKCE")
struct PKCETests {
    @Test("Verifier length is what was requested")
    func verifierLength() {
        let pair = PKCE.generate(verifierLength: 64)
        #expect(pair.verifier.count == 64)
    }

    @Test("Challenge is base64url(SHA256(verifier))")
    func challengeMatchesSpec() {
        let pair = PKCE.generate(verifierLength: 64)
        let expected = Data(SHA256.hash(data: Data(pair.verifier.utf8))).base64URLEncodedString()
        #expect(pair.challenge == expected)
        #expect(pair.challengeMethod == "S256")
    }

    @Test("Verifier alphabet is URL-safe per RFC 7636")
    func urlSafeAlphabet() {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let pair = PKCE.generate(verifierLength: 64)
        for ch in pair.verifier {
            #expect(allowed.contains(ch))
        }
    }
}
