import Foundation

/// Authentication flows for Coder deployments: OIDC, GitHub OAuth, password.
public enum Auth {
    public static let callbackURLScheme = "workspaceterminal"
    public static let callbackHost = "auth"
    public static let callbackPath = "/callback"

    /// Full callback URL for OIDC redirects.
    public static var callbackURL: URL {
        URL(string: "\(callbackURLScheme)://\(callbackHost)\(callbackPath)")!
    }
}
