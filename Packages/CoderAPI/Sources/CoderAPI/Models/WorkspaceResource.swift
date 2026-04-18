import Foundation

/// A resource (e.g. a Docker container, VM, etc.) created by a workspace build.
/// May contain one or more `WorkspaceAgent`s.
public struct WorkspaceResource: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let type: String
    public let createdAt: Date
    public let jobID: UUID
    public let workspaceTransition: WorkspaceBuild.Transition
    public let icon: String?
    public let agents: [WorkspaceAgent]

    public init(
        id: UUID,
        name: String,
        type: String,
        createdAt: Date,
        jobID: UUID,
        workspaceTransition: WorkspaceBuild.Transition,
        icon: String? = nil,
        agents: [WorkspaceAgent] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
        self.jobID = jobID
        self.workspaceTransition = workspaceTransition
        self.icon = icon
        self.agents = agents
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case createdAt = "created_at"
        case jobID = "job_id"
        case workspaceTransition = "workspace_transition"
        case icon
        case agents
    }
}
