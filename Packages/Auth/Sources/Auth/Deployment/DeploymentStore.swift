import CoderAPI
import Foundation

/// Persistent store for deployments + their session tokens.
///
/// Holds:
///   - The list of all known deployments the user has signed into
///   - The id of the currently active deployment (if any)
///
/// Both are persisted as a single JSON blob in the Keychain so reads /
/// writes are atomic.
public protocol DeploymentStore: Sendable {
    /// Snapshot of all known deployments.
    func allDeployments() async throws -> [StoredDeployment]

    /// The currently active deployment, if any.
    func activeDeployment() async throws -> StoredDeployment?

    /// Add a new deployment (or update an existing one with the same id) and
    /// mark it active.
    func upsertActive(_ deployment: StoredDeployment) async throws

    /// Switch the active deployment to one already in the known list.
    /// Throws `DeploymentStoreError.notFound` if the id is unknown.
    func switchActive(to id: UUID) async throws

    /// Update the token for an existing deployment.
    func updateToken(deploymentID: UUID, token: SessionToken) async throws

    /// Remove a deployment. If it was active, the new active deployment is
    /// the most recently created remaining one (or none).
    func remove(id: UUID) async throws

    /// Forget every deployment.
    func reset() async throws
}

public enum DeploymentStoreError: Error, Sendable, Equatable {
    case notFound(UUID)
    case keychain(KeychainError)
    case decoding(String)
    case encoding(String)
}

/// `DeploymentStore` backed by a `KeychainClient`.
public actor LiveDeploymentStore: DeploymentStore {
    private let keychain: any KeychainClient
    private let storageKey: String

    public init(
        keychain: any KeychainClient,
        storageKey: String = "deployments.v1"
    ) {
        self.keychain = keychain
        self.storageKey = storageKey
    }

    public func allDeployments() async throws -> [StoredDeployment] {
        try await loadEnvelope().deployments
    }

    public func activeDeployment() async throws -> StoredDeployment? {
        let env = try await loadEnvelope()
        guard let activeID = env.activeID else { return nil }
        return env.deployments.first(where: { $0.id == activeID })
    }

    public func upsertActive(_ deployment: StoredDeployment) async throws {
        var env = try await loadEnvelope()
        if let index = env.deployments.firstIndex(where: { $0.id == deployment.id }) {
            env.deployments[index] = deployment
        } else {
            env.deployments.append(deployment)
        }
        env.activeID = deployment.id
        try await save(env)
    }

    public func switchActive(to id: UUID) async throws {
        var env = try await loadEnvelope()
        guard env.deployments.contains(where: { $0.id == id }) else {
            throw DeploymentStoreError.notFound(id)
        }
        env.activeID = id
        try await save(env)
    }

    public func updateToken(deploymentID: UUID, token: SessionToken) async throws {
        var env = try await loadEnvelope()
        guard let index = env.deployments.firstIndex(where: { $0.id == deploymentID }) else {
            throw DeploymentStoreError.notFound(deploymentID)
        }
        env.deployments[index].token = token
        try await save(env)
    }

    public func remove(id: UUID) async throws {
        var env = try await loadEnvelope()
        env.deployments.removeAll(where: { $0.id == id })
        if env.activeID == id {
            env.activeID = env.deployments
                .sorted(by: { $0.deployment.createdAt > $1.deployment.createdAt })
                .first?.id
        }
        try await save(env)
    }

    public func reset() async throws {
        do {
            try await keychain.delete(key: storageKey)
        } catch let error as KeychainError {
            throw DeploymentStoreError.keychain(error)
        }
    }

    // MARK: - Envelope

    private struct Envelope: Codable, Sendable {
        var deployments: [StoredDeployment]
        var activeID: UUID?

        static let empty = Envelope(deployments: [], activeID: nil)
    }

    private func loadEnvelope() async throws -> Envelope {
        let data: Data?
        do {
            data = try await keychain.get(key: storageKey)
        } catch let error as KeychainError {
            throw DeploymentStoreError.keychain(error)
        }
        guard let data else { return .empty }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw DeploymentStoreError.decoding(String(describing: error))
        }
    }

    private func save(_ env: Envelope) async throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(env)
        } catch {
            throw DeploymentStoreError.encoding(String(describing: error))
        }
        do {
            try await keychain.set(key: storageKey, value: data)
        } catch let error as KeychainError {
            throw DeploymentStoreError.keychain(error)
        }
    }
}
