import Foundation

/// A single workspace build. Created on workspace start/stop/restart transitions.
public struct WorkspaceBuild: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let workspaceID: UUID
    public let workspaceName: String
    public let workspaceOwnerID: UUID
    public let workspaceOwnerName: String
    public let templateVersionID: UUID
    public let buildNumber: Int
    public let transition: Transition
    public let initiatorID: UUID
    public let initiatorName: String
    public let job: ProvisionerJob
    public let reason: Reason
    public let resources: [WorkspaceResource]
    public let createdAt: Date
    public let updatedAt: Date
    public let deadline: Date?

    /// Convenience: derived from the embedded job's status.
    public var status: Status { job.status.workspaceBuildStatus(transition: transition) }

    public init(
        id: UUID,
        workspaceID: UUID,
        workspaceName: String,
        workspaceOwnerID: UUID,
        workspaceOwnerName: String,
        templateVersionID: UUID,
        buildNumber: Int,
        transition: Transition,
        initiatorID: UUID,
        initiatorName: String,
        job: ProvisionerJob,
        reason: Reason = .initiator,
        resources: [WorkspaceResource] = [],
        createdAt: Date,
        updatedAt: Date,
        deadline: Date? = nil
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.workspaceName = workspaceName
        self.workspaceOwnerID = workspaceOwnerID
        self.workspaceOwnerName = workspaceOwnerName
        self.templateVersionID = templateVersionID
        self.buildNumber = buildNumber
        self.transition = transition
        self.initiatorID = initiatorID
        self.initiatorName = initiatorName
        self.job = job
        self.reason = reason
        self.resources = resources
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deadline = deadline
    }

    public enum Transition: String, Sendable, Hashable, Codable, CaseIterable {
        case start
        case stop
        case delete
    }

    public enum Reason: String, Sendable, Hashable, Codable {
        case initiator
        case autostart
        case autostop
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Reason(rawValue: raw) ?? .unknown
        }
    }

    /// User-facing status the UI surfaces. Combines transition + job status.
    public enum Status: String, Sendable, Hashable, CaseIterable {
        case starting
        case running
        case stopping
        case stopped
        case deleting
        case deleted
        case failed
        case pending
        case canceling
        case canceled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceID = "workspace_id"
        case workspaceName = "workspace_name"
        case workspaceOwnerID = "workspace_owner_id"
        case workspaceOwnerName = "workspace_owner_name"
        case templateVersionID = "template_version_id"
        case buildNumber = "build_number"
        case transition
        case initiatorID = "initiator_id"
        case initiatorName = "initiator_name"
        case job
        case reason
        case resources
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deadline
    }

    // Defensive decode — Coder may omit `resources` on early-stage builds
    // and `reason` on legacy data; default both rather than failing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.workspaceID = try container.decode(UUID.self, forKey: .workspaceID)
        self.workspaceName = try container.decode(String.self, forKey: .workspaceName)
        self.workspaceOwnerID = try container.decode(UUID.self, forKey: .workspaceOwnerID)
        self.workspaceOwnerName = try container.decode(String.self, forKey: .workspaceOwnerName)
        self.templateVersionID = try container.decode(UUID.self, forKey: .templateVersionID)
        self.buildNumber = try container.decode(Int.self, forKey: .buildNumber)
        self.transition = try container.decode(Transition.self, forKey: .transition)
        self.initiatorID = try container.decode(UUID.self, forKey: .initiatorID)
        self.initiatorName = try container.decode(String.self, forKey: .initiatorName)
        self.job = try container.decode(ProvisionerJob.self, forKey: .job)
        self.reason = try container.decodeIfPresent(Reason.self, forKey: .reason) ?? .initiator
        self.resources = try container.decodeIfPresent([WorkspaceResource].self, forKey: .resources) ?? []
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
    }
}

/// Coder's provisioner job — the unit of work that performs a build transition.
public struct ProvisionerJob: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let status: ProvisionerJobStatus
    public let createdAt: Date
    public let startedAt: Date?
    public let completedAt: Date?
    public let canceledAt: Date?
    public let error: String?

    public init(
        id: UUID,
        status: ProvisionerJobStatus,
        createdAt: Date,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        canceledAt: Date? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.canceledAt = canceledAt
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case canceledAt = "canceled_at"
        case error
    }
}

public enum ProvisionerJobStatus: String, Sendable, Hashable, Codable, CaseIterable {
    case pending
    case running
    case succeeded
    case failed
    case canceling
    case canceled
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ProvisionerJobStatus(rawValue: raw) ?? .unknown
    }

    /// Map the job status to a workspace-build user-facing status, given the
    /// transition the build is performing.
    public func workspaceBuildStatus(transition: WorkspaceBuild.Transition) -> WorkspaceBuild.Status {
        switch (self, transition) {
        case (.pending, _):              return .pending
        case (.running, .start):         return .starting
        case (.running, .stop):          return .stopping
        case (.running, .delete):        return .deleting
        case (.succeeded, .start):       return .running
        case (.succeeded, .stop):        return .stopped
        case (.succeeded, .delete):      return .deleted
        case (.failed, _):               return .failed
        case (.canceling, _):            return .canceling
        case (.canceled, _):             return .canceled
        case (.unknown, _):              return .pending
        }
    }
}
