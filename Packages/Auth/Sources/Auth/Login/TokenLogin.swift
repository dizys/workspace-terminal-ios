import CoderAPI
import Foundation

/// Performs a session-token login against a Coder deployment.
///
/// The simplest auth flow: the user provides a pre-existing session token
/// (generated via `coder tokens create` or the Coder web UI). We validate
/// it by calling `GET /api/v2/users/me`.
///
/// Pure flow logic — owns no state of its own. Caller is responsible for
/// persisting the resulting `StoredDeployment` via `DeploymentStore`.
public struct TokenLogin: Sendable {
    public let userAgent: String
    public let clientFactory: @Sendable (Deployment, TLSConfig, @escaping @Sendable () -> SessionToken?) -> any CoderAPIClient

    public init(
        userAgent: String,
        clientFactory: @escaping @Sendable (Deployment, TLSConfig, @escaping @Sendable () -> SessionToken?) -> any CoderAPIClient
    ) {
        self.userAgent = userAgent
        self.clientFactory = clientFactory
    }

    public init(userAgent: String) {
        self.userAgent = userAgent
        self.clientFactory = { deployment, tls, tokenProvider in
            LiveCoderAPIClient(
                deployment: deployment,
                tls: tls,
                userAgent: userAgent,
                tokenProvider: tokenProvider
            )
        }
    }

    /// Sign in to `deployment` with a raw session token.
    ///
    /// On success, returns a fully-formed `StoredDeployment` ready to be
    /// passed to `DeploymentStore.upsertActive(_:)`.
    public func signIn(
        deployment: Deployment,
        rawToken: String,
        tls: TLSConfig = .default
    ) async throws -> StoredDeployment {
        let token = SessionToken(rawToken)
        let client = clientFactory(deployment, tls, { token })
        let user = try await client.fetchCurrentUser()

        let resolved = Deployment(
            id: deployment.id,
            baseURL: deployment.baseURL,
            displayName: deployment.displayName,
            username: user.username,
            createdAt: deployment.createdAt
        )
        return StoredDeployment(deployment: resolved, token: token, trustedCAs: tls.trustedCAs)
    }
}
