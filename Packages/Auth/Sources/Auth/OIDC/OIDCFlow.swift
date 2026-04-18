import CoderAPI
import Foundation

/// Handles browser-based sign-in flows (OIDC + GitHub OAuth) by routing the
/// user through Coder's `/cli-auth` page.
///
/// **Why /cli-auth instead of /api/v2/users/oidc/authenticate with a custom
/// redirect URL?**
///
/// Coder's authenticate endpoints don't redirect to arbitrary external URL
/// schemes (`workspaceterminal://`) — they only redirect to absolute https
/// URLs registered as the deployment's redirect_uri, then set a cookie on
/// the deployment's own host. There is no way to pipe a session token back
/// to a native iOS app via that flow without a server-side redirect helper.
///
/// `/cli-auth` is the official solution: the same endpoint Coder's `coder
/// login` CLI uses. It routes through whatever auth method the deployment
/// has configured (OIDC / GitHub / password), then renders a one-time
/// session token. We take it from the page's `?session_token=...` query
/// parameter via ASWebAuthenticationSession's redirect detection by
/// pointing the auth session at a URL we know Coder will navigate to AFTER
/// the user lands on the token page — which is `<deployment>/cli-auth`
/// with a final navigation that includes the token.
///
/// Implementation: open `<deployment>/cli-auth?redirect_uri=workspaceterminal://auth/callback`.
/// Coder will: (1) handle auth in the user's chosen flow, (2) generate a
/// session token, (3) redirect to our custom URL scheme with
/// `?session_token=<token>`. ASWebAuthenticationSession resolves with that
/// URL and we parse the token from it.
///
/// If `redirect_uri` is rejected by an old Coder deployment, fall back to
/// having the user copy-paste the token from the rendered page (out of
/// scope for v1 — we tell them to upgrade).
public struct OIDCFlow: Sendable {
    public enum Provider: Sendable, Equatable {
        case oidc
        case github

        /// Hint to Coder which auth method to use, passed as `?provider=`.
        /// Coder ignores this if only one method is enabled.
        var providerHint: String? {
            switch self {
            case .oidc:   return "oidc"
            case .github: return "github"
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
        let authURL = buildAuthURL(deployment: deployment, provider: provider)
        let callbackURL = try await session.start(authURL: authURL, callbackScheme: Auth.callbackURLScheme)

        let token = try extractToken(from: callbackURL)

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

    /// Build the URL we hand to ASWebAuthenticationSession. Points to the
    /// deployment's `/cli-auth` page with our custom-scheme redirect_uri.
    func buildAuthURL(deployment: Deployment, provider: Provider) -> URL {
        // /cli-auth lives at the dashboard root, not under /api/v2.
        var components = URLComponents(url: deployment.baseURL, resolvingAgainstBaseURL: false)!
        let basePath = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        components.path = "\(basePath)/cli-auth"

        var items: [URLQueryItem] = [
            URLQueryItem(name: "redirect_uri", value: Auth.callbackURL.absoluteString),
        ]
        if let hint = provider.providerHint {
            items.append(URLQueryItem(name: "provider", value: hint))
        }
        components.queryItems = items
        return components.url!
    }

    /// Pull `session_token` from the redirect URL Coder sent us.
    func extractToken(from callbackURL: URL) throws -> SessionToken {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            throw OIDCError.missingTokenInCallback
        }
        // Coder's CLI-auth page emits the token as `session_token`; some
        // older builds use `cli_session` — accept both.
        let candidates = ["session_token", "cli_session", "token"]
        for key in candidates {
            if let value = items.first(where: { $0.name == key })?.value, !value.isEmpty {
                return SessionToken(value)
            }
        }
        throw OIDCError.missingTokenInCallback
    }
}
