import Foundation
import Testing
@testable import CoderAPI

@Suite("Auth endpoints")
struct AuthEndpointTests {
    init() { StubURLProtocol.reset() }

    @Test("fetchAuthMethods decodes the response")
    func fetchAuthMethods() async throws {
        StubURLProtocol.register(
            method: "GET",
            pathSuffix: "/api/v2/users/authmethods",
            response: .init(body: Fixtures.json(#"""
            { "password": {"enabled": true}, "github": {"enabled": false}, "oidc": {"enabled": false} }
            """#))
        )
        let methods = try await Fixtures.client().fetchAuthMethods()
        #expect(methods.password.enabled)
    }

    @Test("login posts credentials and decodes the session token")
    func login() async throws {
        StubURLProtocol.register(
            method: "POST",
            pathSuffix: "/api/v2/users/login",
            response: .init(body: Fixtures.json(#"{ "session_token": "tok-abc" }"#))
        )
        let token = try await Fixtures.client().login(email: "a@b.com", password: "x")
        #expect(token.value == "tok-abc")
    }

    @Test("login surfaces 401 as .unauthorized")
    func loginUnauthorized() async throws {
        StubURLProtocol.register(
            method: "POST",
            pathSuffix: "/api/v2/users/login",
            response: .init(status: 401, body: Fixtures.json(#"{ "message": "Invalid credentials" }"#))
        )
        await #expect(throws: CoderAPIError.unauthorized(message: "Invalid credentials")) {
            _ = try await Fixtures.client().login(email: "a@b.com", password: "x")
        }
    }

    @Test("Server 500 surfaces as .http with the parsed message")
    func serverError() async throws {
        StubURLProtocol.register(
            method: "GET",
            pathSuffix: "/api/v2/users/me",
            response: .init(status: 500, body: Fixtures.json(#"{ "message": "boom" }"#))
        )
        do {
            _ = try await Fixtures.client().fetchCurrentUser()
            Issue.record("Expected throw")
        } catch let CoderAPIError.http(status, message, _) {
            #expect(status == 500)
            #expect(message == "boom")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
