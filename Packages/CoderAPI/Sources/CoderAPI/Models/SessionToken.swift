import Foundation

/// Coder session token. Sent as the `Coder-Session-Token` request header.
///
/// `description` is redacted; never log the raw value via standard logging APIs.
public struct SessionToken: Sendable, Hashable, Codable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public var description: String { "<SessionToken redacted>" }

    public static let httpHeaderName = "Coder-Session-Token"
}

extension SessionToken: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
