import Foundation

/// A Coder workspace. Mirrors `GET /api/v2/workspaces/{id}` and entries in `GET /api/v2/workspaces`.
public struct Workspace: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let ownerID: UUID
    public let ownerName: String
    public let templateID: UUID
    public let templateName: String
    public let templateDisplayName: String?
    public let templateIcon: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let lastUsedAt: Date?
    public let outdated: Bool
    public let autostartSchedule: String?
    public let ttlMillis: Int64?
    public let latestBuild: WorkspaceBuild

    public var isRunning: Bool { latestBuild.status == .running }
    public var canStart: Bool { latestBuild.status == .stopped || latestBuild.status == .failed }
    public var canStop: Bool { latestBuild.status == .running }
    public var canRestart: Bool { latestBuild.status == .running }

    public init(
        id: UUID,
        name: String,
        ownerID: UUID,
        ownerName: String,
        templateID: UUID,
        templateName: String,
        templateDisplayName: String? = nil,
        templateIcon: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        lastUsedAt: Date? = nil,
        outdated: Bool = false,
        autostartSchedule: String? = nil,
        ttlMillis: Int64? = nil,
        latestBuild: WorkspaceBuild
    ) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.templateID = templateID
        self.templateName = templateName
        self.templateDisplayName = templateDisplayName
        self.templateIcon = templateIcon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.outdated = outdated
        self.autostartSchedule = autostartSchedule
        self.ttlMillis = ttlMillis
        self.latestBuild = latestBuild
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerID = "owner_id"
        case ownerName = "owner_name"
        case templateID = "template_id"
        case templateName = "template_name"
        case templateDisplayName = "template_display_name"
        case templateIcon = "template_icon"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastUsedAt = "last_used_at"
        case outdated
        case autostartSchedule = "autostart_schedule"
        case ttlMillis = "ttl_ms"
        case latestBuild = "latest_build"
    }
}

/// Server response shape for `GET /api/v2/workspaces`.
public struct WorkspacesResponse: Sendable, Codable {
    public let workspaces: [Workspace]
    public let count: Int

    public init(workspaces: [Workspace], count: Int) {
        self.workspaces = workspaces
        self.count = count
    }
}
