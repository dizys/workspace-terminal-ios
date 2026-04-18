import CoderAPI
import ComposableArchitecture
import Foundation

/// Provider for the active session token. Wired at app composition time
/// (`WorkspaceTerminalApp`) from the `DeploymentStore`. Mirrors the
/// `AuthenticatedAPIClientProvider` pattern in WorkspaceFeature.
public struct AuthenticatedSessionTokenProvider: Sendable {
    public let resolve: @Sendable () async -> SessionToken?

    public init(resolve: @escaping @Sendable () async -> SessionToken?) {
        self.resolve = resolve
    }

    public func callAsFunction() async -> SessionToken? { await resolve() }
}

extension AuthenticatedSessionTokenProvider: DependencyKey {
    public static let liveValue = AuthenticatedSessionTokenProvider { nil }
    public static let testValue = AuthenticatedSessionTokenProvider { nil }
}

extension DependencyValues {
    public var authenticatedSessionToken: AuthenticatedSessionTokenProvider {
        get { self[AuthenticatedSessionTokenProvider.self] }
        set { self[AuthenticatedSessionTokenProvider.self] = newValue }
    }
}
