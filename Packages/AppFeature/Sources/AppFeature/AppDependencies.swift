import Auth
import CoderAPI
import ComposableArchitecture
import Foundation

/// `DependencyKey` for the `DeploymentStore`. Live value is built by the
/// App composition root with a real Keychain.
public struct DeploymentStoreDependency: Sendable {
    public let store: any DeploymentStore

    public init(_ store: any DeploymentStore) {
        self.store = store
    }
}

extension DeploymentStoreDependency {
    public func allDeployments() async throws -> [StoredDeployment] {
        try await store.allDeployments()
    }
    public func activeDeployment() async throws -> StoredDeployment? {
        try await store.activeDeployment()
    }
    public func upsertActive(_ deployment: StoredDeployment) async throws {
        try await store.upsertActive(deployment)
    }
    public func switchActive(to id: UUID) async throws {
        try await store.switchActive(to: id)
    }
    public func updateToken(deploymentID: UUID, token: SessionToken) async throws {
        try await store.updateToken(deploymentID: deploymentID, token: token)
    }
    public func remove(id: UUID) async throws {
        try await store.remove(id: id)
    }
    public func reset() async throws {
        try await store.reset()
    }
}

extension DeploymentStoreDependency: DependencyKey {
    public static let liveValue: DeploymentStoreDependency = .init(
        LiveDeploymentStore(keychain: LiveKeychainClient())
    )
    public static var testValue: DeploymentStoreDependency {
        .init(LiveDeploymentStore(keychain: InMemoryKeychainClient()))
    }
}

extension DependencyValues {
    public var deploymentStore: DeploymentStoreDependency {
        get { self[DeploymentStoreDependency.self] }
        set { self[DeploymentStoreDependency.self] = newValue }
    }
}
