import Foundation

/// Public namespace + version banner for the Coder REST API client.
public enum CoderAPI {
    public static let version = "0.1.0"

    /// `User-Agent` header sent on every request, including app version + platform.
    public static func userAgent(appVersion: String, build: String) -> String {
        "WorkspaceTerminal/\(appVersion) (\(build); iOS) CoderAPI/\(version)"
    }
}
