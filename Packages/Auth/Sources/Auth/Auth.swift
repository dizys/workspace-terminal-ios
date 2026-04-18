import Foundation

/// Authentication flows for Coder deployments: OIDC, GitHub OAuth, password.
public enum Auth {
    public static let callbackURLScheme = "coderterminal"
    public static let callbackHost = "auth"
    public static let callbackPath = "/callback"
}

public enum AuthMethod: Sendable, Hashable {
    case password
    case github
    case oidc(displayName: String, iconURL: URL?)
}

public struct SessionToken: Sendable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}
