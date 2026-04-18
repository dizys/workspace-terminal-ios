import Foundation

/// A Coder deployment a user has signed into.
///
/// Stored persistently in the Keychain via the Auth package. The `id` is generated
/// locally on first sign-in and stable for the life of the deployment record.
public struct Deployment: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let baseURL: URL
    public let displayName: String
    public let username: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        baseURL: URL,
        displayName: String,
        username: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.baseURL = baseURL
        self.displayName = displayName
        self.username = username
        self.createdAt = createdAt
    }

    /// Build a fully-qualified API URL by appending a path under `/api/v2`.
    public func apiURL(path: String) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            preconditionFailure("Invalid base URL: \(baseURL)")
        }
        let trimmedBasePath = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        components.path = "\(trimmedBasePath)/api/v2\(normalized)"
        guard let url = components.url else {
            preconditionFailure("Failed to build API URL for path \(path) on \(baseURL)")
        }
        return url
    }
}
