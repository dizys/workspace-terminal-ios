import CoderAPI
import Foundation
import Testing
@testable import Auth

@Suite("OIDCFlow URL building")
struct OIDCFlowURLTests {
    @Test("Builds /cli-auth URL with redirect_uri + provider hint for OIDC")
    func oidcURL() {
        let flow = OIDCFlow(userAgent: "test", session: FakeAuthSession(callback: URL(string: "x://x")!))
        let dep = Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: "x")
        let url = flow.buildAuthURL(deployment: dep, provider: .oidc)
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(comps.path == "/cli-auth")
        let q = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).compactMap { item in
            item.value.map { v in (item.name, v) }
        })
        #expect(q["redirect_uri"] == Auth.callbackURL.absoluteString)
        #expect(q["provider"] == "oidc")
    }

    @Test("Hints provider=github for .github")
    func githubURL() {
        let flow = OIDCFlow(userAgent: "test", session: FakeAuthSession(callback: URL(string: "x://x")!))
        let dep = Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: "x")
        let url = flow.buildAuthURL(deployment: dep, provider: .github)
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(comps.path == "/cli-auth")
        let q = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).compactMap { item in
            item.value.map { v in (item.name, v) }
        })
        #expect(q["provider"] == "github")
    }

    @Test("Handles deployment URL with subpath")
    func subpathURL() {
        let flow = OIDCFlow(userAgent: "test", session: FakeAuthSession(callback: URL(string: "x://x")!))
        let dep = Deployment(baseURL: URL(string: "https://corp.com/coder")!, displayName: "x")
        let url = flow.buildAuthURL(deployment: dep, provider: .oidc)
        #expect(url.path == "/coder/cli-auth")
    }

    @Test("extractToken finds session_token query param")
    func extractSessionToken() throws {
        let flow = OIDCFlow(userAgent: "test", session: FakeAuthSession(callback: URL(string: "x://x")!))
        let cb = URL(string: "workspaceterminal://auth/callback?session_token=abc-123")!
        let token = try flow.extractToken(from: cb)
        #expect(token.value == "abc-123")
    }

    @Test("extractToken accepts cli_session as a fallback name")
    func extractCLISession() throws {
        let flow = OIDCFlow(userAgent: "test", session: FakeAuthSession(callback: URL(string: "x://x")!))
        let cb = URL(string: "workspaceterminal://auth/callback?cli_session=tok-xyz")!
        let token = try flow.extractToken(from: cb)
        #expect(token.value == "tok-xyz")
    }

    @Test("extractToken throws when token is missing")
    func extractMissing() throws {
        let flow = OIDCFlow(userAgent: "test", session: FakeAuthSession(callback: URL(string: "x://x")!))
        let cb = URL(string: "workspaceterminal://auth/callback?error=denied")!
        #expect(throws: OIDCFlow.OIDCError.missingTokenInCallback) {
            _ = try flow.extractToken(from: cb)
        }
    }
}

private struct FakeAuthSession: OIDCFlow.AuthSession {
    let callback: URL
    func start(authURL: URL, callbackScheme: String) async throws -> URL { callback }
}
