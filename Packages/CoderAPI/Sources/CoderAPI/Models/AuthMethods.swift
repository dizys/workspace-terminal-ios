import Foundation

/// Auth methods enabled on a Coder deployment. Mirrors `GET /api/v2/users/authmethods`.
///
/// Used by the login screen to render only the buttons for enabled methods.
public struct AuthMethods: Sendable, Hashable, Codable {
    public let password: PasswordMethod
    public let github: GitHubMethod
    public let oidc: OIDCMethod

    public init(password: PasswordMethod, github: GitHubMethod, oidc: OIDCMethod) {
        self.password = password
        self.github = github
        self.oidc = oidc
    }

    public struct PasswordMethod: Sendable, Hashable, Codable {
        public let enabled: Bool
        public init(enabled: Bool) { self.enabled = enabled }
    }

    public struct GitHubMethod: Sendable, Hashable, Codable {
        public let enabled: Bool
        public init(enabled: Bool) { self.enabled = enabled }
    }

    public struct OIDCMethod: Sendable, Hashable, Codable {
        public let enabled: Bool
        public let signInText: String?
        public let iconURL: URL?

        public init(enabled: Bool, signInText: String? = nil, iconURL: URL? = nil) {
            self.enabled = enabled
            self.signInText = signInText
            self.iconURL = iconURL
        }

        enum CodingKeys: String, CodingKey {
            case enabled
            case signInText
            case iconURL = "iconUrl"
        }

        // Coder returns iconUrl as an empty string ("") when no icon is
        // configured. Foundation's URL(string: "") returns nil and the
        // synthesized Codable conformance throws .dataCorrupted on a nil URL.
        // Use LenientURL to degrade gracefully — empty/malformed URLs become nil.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.enabled = try container.decode(Bool.self, forKey: .enabled)
            let signIn = try container.decodeIfPresent(String.self, forKey: .signInText)
            self.signInText = (signIn?.isEmpty == false) ? signIn : nil
            self.iconURL = try LenientURL.decode(from: container, forKey: .iconURL)
        }
    }

    /// Convenience: list of enabled auth methods for the login screen, in display order.
    public var enabledMethods: [AuthMethod] {
        var result: [AuthMethod] = []
        if oidc.enabled {
            result.append(.oidc(displayText: oidc.signInText ?? "Continue with SSO", iconURL: oidc.iconURL))
        }
        if github.enabled {
            result.append(.github)
        }
        if password.enabled {
            result.append(.password)
        }
        return result
    }
}

/// A single auth method to render on the login screen.
public enum AuthMethod: Sendable, Hashable {
    case password
    case github
    case oidc(displayText: String, iconURL: URL?)
}
