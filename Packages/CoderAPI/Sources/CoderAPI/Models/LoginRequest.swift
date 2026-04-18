import Foundation

/// Request body for `POST /api/v2/users/login`.
public struct LoginRequest: Sendable, Equatable, Encodable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// Response body for `POST /api/v2/users/login`.
public struct LoginResponse: Sendable, Equatable, Decodable {
    public let sessionToken: String

    public init(sessionToken: String) {
        self.sessionToken = sessionToken
    }

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
    }
}

/// Request body for `POST /api/v2/workspaces/{id}/builds`.
public struct CreateBuildRequest: Sendable, Equatable, Encodable {
    public let transition: WorkspaceBuild.Transition

    public init(transition: WorkspaceBuild.Transition) {
        self.transition = transition
    }
}
