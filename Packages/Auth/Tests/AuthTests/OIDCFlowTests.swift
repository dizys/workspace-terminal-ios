import CoderAPI
import Foundation
import Testing
@testable import Auth

@Suite("OIDCFlow URL building")
struct OIDCFlowURLTests {
    @Test("Builds OIDC auth URL with redirect + state")
    func oidcURL() {
        let flow = OIDCFlow(userAgent: "test", session: FakeAuthSession(callback: URL(string: "x://x")!))
        let dep = Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: "x")
        let url = flow.buildAuthURL(deployment: dep, provider: .oidc, state: "STATE_A")
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(comps.path.hasSuffix("/api/v2/users/oidc/callback"))
        let q = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).compactMap { item in
            item.value.map { v in (item.name, v) }
        })
        #expect(q["state"] == "STATE_A")
        #expect(q["redirect"] == Auth.callbackURL.absoluteString)
    }

    @Test("Uses GitHub callback path for .github provider")
    func githubURL() {
        let flow = OIDCFlow(userAgent: "test", session: FakeAuthSession(callback: URL(string: "x://x")!))
        let dep = Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: "x")
        let url = flow.buildAuthURL(deployment: dep, provider: .github, state: "S")
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)!.path
                .hasSuffix("/api/v2/users/oauth2/github/callback"))
    }
}

private struct FakeAuthSession: OIDCFlow.AuthSession {
    let callback: URL
    func start(authURL: URL, callbackScheme: String) async throws -> URL { callback }
}
