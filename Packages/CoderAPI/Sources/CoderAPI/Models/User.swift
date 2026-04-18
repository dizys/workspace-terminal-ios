import Foundation

/// A Coder user. Mirrors the response of `GET /api/v2/users/me`.
public struct User: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let username: String
    public let email: String
    public let name: String?
    public let avatarURL: URL?
    public let status: Status
    public let roles: [Role]
    public let createdAt: Date
    public let lastSeenAt: Date?

    public enum Status: String, Sendable, Hashable, Codable, CaseIterable {
        case active
        case suspended
        case dormant
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Status(rawValue: raw) ?? .unknown
        }
    }

    public struct Role: Sendable, Hashable, Codable {
        public let name: String
        public let displayName: String?

        public init(name: String, displayName: String? = nil) {
            self.name = name
            self.displayName = displayName
        }

        enum CodingKeys: String, CodingKey {
            case name
            case displayName = "display_name"
        }
    }

    public init(
        id: UUID,
        username: String,
        email: String,
        name: String? = nil,
        avatarURL: URL? = nil,
        status: Status = .active,
        roles: [Role] = [],
        createdAt: Date,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.name = name
        self.avatarURL = avatarURL
        self.status = status
        self.roles = roles
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case name
        case avatarURL = "avatar_url"
        case status
        case roles
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
    }
}
