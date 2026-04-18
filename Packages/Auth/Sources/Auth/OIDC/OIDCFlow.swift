import CoderAPI
import Foundation

/// Handles the OIDC + GitHub OAuth flows that route through Coder's own
/// callback endpoint, then reach our app via the `workspaceterminal://`
/// URL scheme.
///
/// Coder's OIDC integration works by:
///   1. App opens `<deployment>/api/v2/users/oidc/callback?redirect=workspaceterminal://auth/callback`
///      (or the GitHub equivalent) inside `ASWebAuthenticationSession`.
///   2. User authenticates with the OIDC provider.
///   3. Coder server exchanges the code, mints a session token, and
///      redirects back to our scheme with `?session_token=...`.
///   4. We parse the token from the callback URL and persist it.
///
/// PKCE is performed by the Coder server, not by the app, but we generate
/// our own PKCE-style state token that we pass through and verify on the
/// callback to defend against callback-URL spoofing.
public struct OIDCFlow: Sendable {
    public enum Provider: Sendable, Equatable {
        case oidc
        case github

        var authPath: String {
            switch self {
            case .oidc:   return "/users/oidc/callback"
            case .github: return "/users/oauth2/github/callback"
            }
        }
    }

    /// The system-provided session that opens the auth URL and resolves
    /// with the redirect URL. Conformed to by `ASWebAuthenticationSession`
    /// on iOS; tests can substitute a fake.
    public protocol AuthSession: Sendable {
        func start(authURL: URL, callbackScheme: String) async throws -> URL
    }

    public enum OIDCError: Error, Sendable, Equatable {
        case userCanceled
        case missingTokenInCallback
        case stateMismatch
        case underlying(String)
    }

    public let userAgent: String
    public let session: any AuthSession

    public init(userAgent: String, session: any AuthSession) {
        self.userAgent = userAgent
        self.session = session
    }

    /// Run the flow against `deployment`. On success, returns a fully-formed
    /// `StoredDeployment` ready to be passed to `DeploymentStore`.
    public func signIn(deployment: Deployment, provider: Provider) async throws -> StoredDeployment {
        let state = PKCE.randomURLSafeString(length: 32)
        let authURL = buildAuthURL(deployment: deployment, provider: provider, state: state)
        let callbackURL = try await session.start(authURL: authURL, callbackScheme: Auth.callbackURLScheme)

        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            throw OIDCError.missingTokenInCallback
        }
        let query = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        if let returnedState = query["state"], returnedState != state {
            throw OIDCError.stateMismatch
        }
        guard let tokenValue = query["session_token"], !tokenValue.isEmpty else {
            throw OIDCError.missingTokenInCallback
        }
        let token = SessionToken(tokenValue)

        // Resolve username via /users/me before persisting.
        let client = LiveCoderAPIClient(
            deployment: deployment,
            userAgent: userAgent,
            tokenProvider: { token }
        )
        let user = try await client.fetchCurrentUser()

        let resolved = Deployment(
            id: deployment.id,
            baseURL: deployment.baseURL,
            displayName: deployment.displayName,
            username: user.username,
            createdAt: deployment.createdAt
        )
        return StoredDeployment(deployment: resolved, token: token)
    }

    func buildAuthURL(deployment: Deployment, provider: Provider, state: String) -> URL {
        var components = URLComponents(url: deployment.apiURL(path: provider.authPath), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "redirect", value: Auth.callbackURL.absoluteString),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }
}
