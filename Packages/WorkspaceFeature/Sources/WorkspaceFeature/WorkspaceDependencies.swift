import CoderAPI
import ComposableArchitecture
import Foundation

/// Provider that hands a `CoderAPIClient` to feature reducers without them
/// needing to know about the deployment or token.
///
/// The App layer wires this with a closure that consults the active
/// `DeploymentStore` and constructs an authenticated client.
public struct AuthenticatedAPIClientProvider: Sendable {
    public let make: @Sendable () async -> (any CoderAPIClient)?

    public init(make: @escaping @Sendable () async -> (any CoderAPIClient)?) {
        self.make = make
    }

    public func callAsFunction() async -> (any CoderAPIClient)? { await make() }
}

extension AuthenticatedAPIClientProvider: DependencyKey {
    public static let liveValue: AuthenticatedAPIClientProvider = .init(make: { nil })
    public static let testValue: AuthenticatedAPIClientProvider = .init(make: { nil })
}

extension DependencyValues {
    public var authenticatedAPIClient: AuthenticatedAPIClientProvider {
        get { self[AuthenticatedAPIClientProvider.self] }
        set { self[AuthenticatedAPIClientProvider.self] = newValue }
    }
}

/// Equatable error wrapper for use in TCA actions.
public struct WorkspaceFailure: Error, Equatable, Sendable {
    public let message: String
    public init(_ error: any Error) {
        self.message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }
    public init(message: String) { self.message = message }
}
