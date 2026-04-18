import Foundation

/// Public surface of the Coder REST API client.
public enum CoderAPI {
    public static let version = "0.1.0"
}

/// A Coder deployment a user has signed into.
public struct Deployment: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let baseURL: URL
    public let displayName: String

    public init(id: UUID = UUID(), baseURL: URL, displayName: String) {
        self.id = id
        self.baseURL = baseURL
        self.displayName = displayName
    }
}
