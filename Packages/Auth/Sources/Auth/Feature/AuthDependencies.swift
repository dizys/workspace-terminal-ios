import CoderAPI
import ComposableArchitecture
import Foundation

// MARK: - CoderAPI client factory

/// Factory that builds a `CoderAPIClient` for a (deployment, TLS config) pair,
/// without an auth token. Used during the login phase where no token exists yet.
public struct CoderAPIClientFactory: Sendable {
    public let make: @Sendable (Deployment, TLSConfig) -> any CoderAPIClient

    public init(make: @escaping @Sendable (Deployment, TLSConfig) -> any CoderAPIClient) {
        self.make = make
    }

    public func callAsFunction(_ deployment: Deployment, _ tls: TLSConfig) -> any CoderAPIClient {
        make(deployment, tls)
    }
}

extension CoderAPIClientFactory: DependencyKey {
    public static let liveValue: CoderAPIClientFactory = .init { deployment, tls in
        LiveCoderAPIClient(
            deployment: deployment,
            tls: tls,
            userAgent: CoderAPI.userAgent,
            tokenProvider: { nil }
        )
    }

    public static let testValue: CoderAPIClientFactory = .init { deployment, _ in
        UnimplementedCoderAPIClient(deployment: deployment)
    }
}

extension DependencyValues {
    public var coderAPIClientFactory: CoderAPIClientFactory {
        get { self[CoderAPIClientFactory.self] }
        set { self[CoderAPIClientFactory.self] = newValue }
    }
}

// MARK: - PasswordLogin

extension PasswordLogin: DependencyKey {
    public static let liveValue: PasswordLogin = .init(
        userAgent: CoderAPI.userAgent
    )

    public static let testValue: PasswordLogin = .init(
        userAgent: "test",
        clientFactory: { deployment, _, _ in UnimplementedCoderAPIClient(deployment: deployment) }
    )
}

extension DependencyValues {
    public var passwordLogin: PasswordLogin {
        get { self[PasswordLogin.self] }
        set { self[PasswordLogin.self] = newValue }
    }
}

// MARK: - TokenLogin

extension TokenLogin: DependencyKey {
    public static let liveValue: TokenLogin = .init(
        userAgent: CoderAPI.userAgent
    )

    public static let testValue: TokenLogin = .init(
        userAgent: "test",
        clientFactory: { deployment, _, _ in UnimplementedCoderAPIClient(deployment: deployment) }
    )
}

extension DependencyValues {
    public var tokenLogin: TokenLogin {
        get { self[TokenLogin.self] }
        set { self[TokenLogin.self] = newValue }
    }
}

// MARK: - OIDCFlow

extension OIDCFlow: DependencyKey {
    public static let liveValue: OIDCFlow = .init(
        userAgent: CoderAPI.userAgent,
        session: UnimplementedAuthSession()
    )

    public static let testValue: OIDCFlow = .init(
        userAgent: "test",
        session: UnimplementedAuthSession()
    )
}

extension DependencyValues {
    public var oidcFlow: OIDCFlow {
        get { self[OIDCFlow.self] }
        set { self[OIDCFlow.self] = newValue }
    }
}

// MARK: - Test scaffolding

/// `CoderAPIClient` that throws on every method. Use as the default test value
/// so tests must opt in to the methods they exercise (avoids accidental
/// silent passes).
struct UnimplementedCoderAPIClient: CoderAPIClient {
    let deployment: Deployment

    private func fail(_ method: String = #function) -> Never {
        fatalError("UnimplementedCoderAPIClient.\(method)")
    }

    func fetchAuthMethods() async throws -> AuthMethods { fail() }
    func login(email: String, password: String) async throws -> SessionToken { fail() }
    func fetchCurrentUser() async throws -> User { fail() }
    func logout() async throws { fail() }
    func fetchBuildInfo() async throws -> BuildInfo { fail() }
    func listMyWorkspaces() async throws -> [Workspace] { fail() }
    func fetchWorkspace(id: UUID) async throws -> Workspace { fail() }
    func createBuild(workspaceID: UUID, transition: WorkspaceBuild.Transition) async throws -> WorkspaceBuild { fail() }
    func fetchBuild(id: UUID) async throws -> WorkspaceBuild { fail() }
    func streamBuildLogs(buildID: UUID, follow: Bool) async throws -> AsyncThrowingStream<BuildLog, Error> { fail() }
    func listListeningPorts(agentID: UUID) async throws -> [ListeningPort] { fail() }
    func appHost() async throws -> String? { fail() }
    func agentConnectionInfo(agentID: UUID) async throws -> AgentConnectionInfo { fail() }
}

struct UnimplementedAuthSession: OIDCFlow.AuthSession {
    func start(authURL: URL, callbackScheme: String) async throws -> URL {
        fatalError("UnimplementedAuthSession.start called")
    }
}
