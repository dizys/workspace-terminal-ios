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

    // Defensive decode — Coder omits `agents` (and may omit `icon`) for
    // resources that don't have agents (e.g. random_string resources).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.jobID = try container.decode(UUID.self, forKey: .jobID)
        self.workspaceTransition = try container.decode(
            WorkspaceBuild.Transition.self, forKey: .workspaceTransition
        )
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.agents = try container.decodeIfPresent([WorkspaceAgent].self, forKey: .agents) ?? []
    }
}
