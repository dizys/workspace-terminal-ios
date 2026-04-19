import Foundation

/// High-level Coder REST API client.
///
/// Each instance is bound to a single deployment + token provider. Feature
/// code holds an instance via TCA's `@Dependency` injection.
///
/// Endpoint methods live in extensions in `Endpoints/`.
public protocol CoderAPIClient: Sendable {
    var deployment: Deployment { get }

    // Auth
    func fetchAuthMethods() async throws -> AuthMethods
    func login(email: String, password: String) async throws -> SessionToken
    func fetchCurrentUser() async throws -> User
    func logout() async throws

    // Server info
    func fetchBuildInfo() async throws -> BuildInfo

    // Workspaces
    func listMyWorkspaces() async throws -> [Workspace]
    func fetchWorkspace(id: UUID) async throws -> Workspace

    // Builds
    func createBuild(workspaceID: UUID, transition: WorkspaceBuild.Transition) async throws -> WorkspaceBuild
    func fetchBuild(id: UUID) async throws -> WorkspaceBuild
    func streamBuildLogs(buildID: UUID, follow: Bool) async throws -> AsyncThrowingStream<BuildLog, Error>

    // Ports
    func listListeningPorts(agentID: UUID) async throws -> [ListeningPort]
    func appHost() async throws -> String?

    // Tailnet
    func agentConnectionInfo(agentID: UUID) async throws -> AgentConnectionInfo
}

/// Live implementation of `CoderAPIClient` backed by `HTTPClient`.
public struct LiveCoderAPIClient: CoderAPIClient {
    public let deployment: Deployment
    let http: HTTPClient

    public init(
        deployment: Deployment,
        tls: TLSConfig = .default,
        userAgent: String,
        tokenProvider: @escaping @Sendable () async -> SessionToken?
    ) {
        self.deployment = deployment
        self.http = HTTPClient(
            deployment: deployment,
            tls: tls,
            userAgent: userAgent,
            tokenProvider: tokenProvider
        )
    }

    /// Test-friendly initializer that injects a pre-built `URLSession`.
    public init(
        deployment: Deployment,
        tls: TLSConfig = .default,
        userAgent: String,
        session: URLSession,
        tokenProvider: @escaping @Sendable () async -> SessionToken?
    ) {
        self.deployment = deployment
        self.http = HTTPClient(
            deployment: deployment,
            tls: tls,
            userAgent: userAgent,
            session: session,
            tokenProvider: tokenProvider
        )
    }
}
