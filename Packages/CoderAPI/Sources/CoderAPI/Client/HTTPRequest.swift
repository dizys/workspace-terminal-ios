import Foundation

/// A high-level description of an HTTP request to a Coder endpoint.
///
/// Built by endpoint methods on `CoderAPIClient`; consumed by `HTTPClient`
/// which adds auth headers, encodes/decodes JSON, and maps responses to
/// `CoderAPIError`.
public struct HTTPRequest: Sendable {
    public var method: HTTPMethod
    public var path: String
    public var query: [URLQueryItem]
    public var headers: [String: String]
    public var body: Data?
    public var requiresAuth: Bool
    public var idempotencyKey: String?

    public init(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        requiresAuth: Bool = true,
        idempotencyKey: String? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
        self.idempotencyKey = idempotencyKey
    }
}
