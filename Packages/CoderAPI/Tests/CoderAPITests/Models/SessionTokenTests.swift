import Foundation
import Testing
@testable import CoderAPI

@Suite("SessionToken")
struct SessionTokenTests {
    @Test("description redacts the value")
    func descriptionRedacted() {
        let token = SessionToken("super-secret-12345")
        #expect(String(describing: token) == "<SessionToken redacted>")
    }

    @Test("string literal initializer works")
    func stringLiteral() {
        let token: SessionToken = "abc"
        #expect(token.value == "abc")
    }

    @Test("HTTP header name is the documented Coder header")
    func headerName() {
        #expect(SessionToken.httpHeaderName == "Coder-Session-Token")
    }
}
