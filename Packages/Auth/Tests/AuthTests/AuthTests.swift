import CoderAPI
import Testing
@testable import Auth

@Suite("Auth smoke")
struct AuthTests {
    @Test("Callback URL scheme is set")
    func callbackScheme() {
        #expect(Auth.callbackURLScheme == "workspaceterminal")
        #expect(Auth.callbackHost == "auth")
        #expect(Auth.callbackPath == "/callback")
    }

    @Test("Callback URL composes scheme/host/path")
    func callbackURLComposed() {
        #expect(Auth.callbackURL.absoluteString == "workspaceterminal://auth/callback")
    }
}
