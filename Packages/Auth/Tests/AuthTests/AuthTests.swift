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

    @Test("SessionToken wraps a string")
    func tokenWraps() {
        let token = SessionToken("abc123")
        #expect(token.value == "abc123")
    }
}
