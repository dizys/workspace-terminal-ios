import Foundation

/// Typed errors from `CoderAPIClient`. Surfaced to the UI layer for user-facing
/// presentation; never `fatalError` on a network failure.
public enum CoderAPIError: Error, Sendable, Equatable {
    /// The transport (URLSession) failed before getting a response.
    /// Includes connection refused, TLS failure, DNS, timeout.
    case transport(reason: String, underlying: TransportReason)

    /// The server returned a non-2xx HTTP status.
    case http(status: Int, message: String?, requestID: String?)

    /// 401 Unauthorized — token is invalid or expired.
    case unauthorized(message: String?)

    /// 403 Forbidden — token is valid but lacks permission.
    case forbidden(message: String?)

    /// 404 Not Found.
    case notFound(message: String?)

    /// 409 Conflict — common when a workspace transition is in progress.
    case conflict(message: String?)

    /// JSON decode failure on a 2xx response.
    case decoding(reason: String)

    /// JSON encode failure when building a request body.
    case encoding(reason: String)

    /// TLS validation failed and the user has not trusted the deployment's CA.
    case tlsValidation(host: String)

    /// The provided URL or path is malformed.
    case invalidURL(String)

    /// Used to wrap unexpected errors that don't fit the taxonomy.
    case other(String)

    /// Distinguishes high-level transport-failure causes for UI presentation.
    public enum TransportReason: String, Sendable, Equatable {
        case timeout
        case dns
        case connectionRefused = "connection_refused"
        case tls
        case offline
        case other
    }
}

extension CoderAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .transport(reason, _):
            return "Network error: \(reason)"
        case let .http(status, message, _):
            return message ?? "HTTP \(status)"
        case let .unauthorized(message):
            return message ?? "You're not signed in. Sign in again."
        case let .forbidden(message):
            return message ?? "You don't have permission for this action."
        case let .notFound(message):
            return message ?? "Not found."
        case let .conflict(message):
            return message ?? "Action conflicts with the current state."
        case let .decoding(reason):
            return "Couldn't read the server response: \(reason)"
        case let .encoding(reason):
            return "Couldn't build the request: \(reason)"
        case let .tlsValidation(host):
            return "Couldn't verify the server's TLS certificate for \(host). " +
                "Add a custom CA in Settings if your deployment uses one."
        case let .invalidURL(detail):
            return "Invalid URL: \(detail)"
        case let .other(detail):
            return detail
        }
    }
}

/// Coder's standard error response body. Mirrors the shape returned by the
/// server for non-2xx responses, e.g. `{"message": "...", "detail": "..."}`.
public struct CoderErrorBody: Sendable, Equatable, Decodable {
    public let message: String?
    public let detail: String?
    public let validations: [Validation]?

    public struct Validation: Sendable, Equatable, Decodable {
        public let field: String?
        public let detail: String?
    }

    public init(message: String? = nil, detail: String? = nil, validations: [Validation]? = nil) {
        self.message = message
        self.detail = detail
        self.validations = validations
    }

    /// Combine `message` + `detail` (and validations) into a user-presentable string.
    public var userMessage: String? {
        var parts: [String] = []
        if let message, !message.isEmpty { parts.append(message) }
        if let detail, !detail.isEmpty { parts.append(detail) }
        if let validations {
            for v in validations {
                if let f = v.field, let d = v.detail {
                    parts.append("\(f): \(d)")
                } else if let d = v.detail {
                    parts.append(d)
                }
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " — ")
    }
}
