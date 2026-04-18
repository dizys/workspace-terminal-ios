import CoderAPI
import Foundation

/// Performs a username/password login against a Coder deployment.
///
/// Pure flow logic — owns no state of its own. Caller is responsible for
/// persisting the resulting `StoredDeployment` via `DeploymentStore`.
public struct PasswordLogin: Sendable {
    public let userAgent: String
    public let clientFactory: @Sendable (Deployment, TLSConfig, @escaping @Sendable () -> SessionToken?) -> any CoderAPIClient

    public init(
        userAgent: String,
        clientFactory: @escaping @Sendable (Deployment, TLSConfig, @escaping @Sendable () -> SessionToken?) -> any CoderAPIClient
    ) {
        self.userAgent = userAgent
        self.clientFactory = clientFactory
    }

    /// Convenience initializer for the common case of using `LiveCoderAPIClient`.
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

    /// Sign in to `deployment` with email + password.
    ///
    /// On success, returns a fully-formed `StoredDeployment` ready to be
    /// passed to `DeploymentStore.upsertActive(_:)`.
    public func signIn(
        deployment: Deployment,
        email: String,
        password: String,
        tls: TLSConfig = .default
    ) async throws -> StoredDeployment {
        // 1. Anonymous client to do the password login.
        let anonymousClient = clientFactory(deployment, tls, { nil })
        let token = try await anonymousClient.login(email: email, password: password)

        // 2. Token-scoped client to fetch the user record (for username).
        let authedClient = clientFactory(deployment, tls, { token })
        let user = try await authedClient.fetchCurrentUser()

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
