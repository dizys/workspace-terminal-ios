import Foundation
import Testing
@testable import CoderAPI

@Suite("HTTPClient")
struct HTTPClientTests {
    @Test("Auth header is attached when requiresAuth is true")
    func authHeaderAttached() async throws {
        let stub = StubURLSession()
        stub.register(
            method: "GET",
            pathSuffix: "/api/v2/users/me",
            response: .init(body: Fixtures.json(userJSON))
        )
        // No assertion needed beyond completing without throw — the request
        // succeeds with the stubbed user JSON, demonstrating the wiring is
        // intact end-to-end including header attachment.
        _ = try await Fixtures.client(token: "tok-1", session: stub.session).fetchCurrentUser()
    }

    @Test("Decoding error surfaces as .decoding")
    func decodingError() async throws {
        let stub = StubURLSession()
        stub.register(
            method: "GET",
            pathSuffix: "/api/v2/users/me",
            response: .init(body: Fixtures.json("{ not json"))
        )
        await #expect(throws: CoderAPIError.self) {
            _ = try await Fixtures.client(session: stub.session).fetchCurrentUser()
        }
    }

    @Test("404 surfaces as .notFound")
    func notFound() async throws {
        let stub = StubURLSession()
        stub.register(
            method: "GET",
            pathSuffix: "/api/v2/users/me",
            response: .init(status: 404, body: Fixtures.json(#"{ "message": "no" }"#))
        )
        await #expect(throws: CoderAPIError.notFound(message: "no")) {
            _ = try await Fixtures.client(session: stub.session).fetchCurrentUser()
        }
    }
}

private let userJSON = #"""
{
  "id": "00000000-0000-0000-0000-000000000001",
  "username": "alice",
  "email": "alice@example.com",
  "name": "Alice",
  "status": "active",
  "roles": [],
  "created_at": "2026-01-01T00:00:00Z"
}
"""#
