import Foundation

/// An agent running inside a workspace resource. PTY connections are made
/// against an agent's id.
public struct WorkspaceAgent: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let status: Status
    public let lifecycleState: LifecycleState
    public let architecture: String?
    public let operatingSystem: String?
    public let version: String?
    public let directory: String?
    public let expandedDirectory: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let firstConnectedAt: Date?
    public let lastConnectedAt: Date?
    public let disconnectedAt: Date?
    public let parentID: UUID?

    /// Whether this agent is a devcontainer child of another agent.
    public var isDevcontainer: Bool { parentID != nil }

    public init(
        id: UUID,
        name: String,
        status: Status,
        lifecycleState: LifecycleState = .ready,
        architecture: String? = nil,
        operatingSystem: String? = nil,
        version: String? = nil,
        directory: String? = nil,
        expandedDirectory: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        firstConnectedAt: Date? = nil,
        lastConnectedAt: Date? = nil,
        disconnectedAt: Date? = nil,
        parentID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.lifecycleState = lifecycleState
        self.architecture = architecture
        self.operatingSystem = operatingSystem
        self.version = version
        self.directory = directory
        self.expandedDirectory = expandedDirectory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.firstConnectedAt = firstConnectedAt
        self.lastConnectedAt = lastConnectedAt
        self.disconnectedAt = disconnectedAt
        self.parentID = parentID
    }

    public enum Status: String, Sendable, Hashable, Codable, CaseIterable {
        case connecting
        case connected
        case disconnected
        case timeout
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Status(rawValue: raw) ?? .unknown
        }
    }

    /// Lifecycle state reported by the agent itself once connected.
    public enum LifecycleState: String, Sendable, Hashable, Codable, CaseIterable {
        case created
        case starting
        case startTimeout = "start_timeout"
        case startError = "start_error"
        case ready
        case shuttingDown = "shutting_down"
        case shutdownTimeout = "shutdown_timeout"
        case shutdownError = "shutdown_error"
        case off
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = LifecycleState(rawValue: raw) ?? .unknown
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case lifecycleState = "lifecycle_state"
        case architecture
        case operatingSystem = "operating_system"
        case version
        case directory
        case expandedDirectory = "expanded_directory"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case firstConnectedAt = "first_connected_at"
        case lastConnectedAt = "last_connected_at"
        case disconnectedAt = "disconnected_at"
        case parentID = "parent_id"
    }
}
