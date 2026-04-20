import Foundation

/// Public namespace + version banner for the Coder REST API client.
public enum CoderAPI {
    /// App marketing version read from the main bundle's Info.plist at runtime.
    /// Falls back to `"0.0.0"` in test targets where the bundle has no version.
    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// App build number read from the main bundle's Info.plist at runtime.
    public static var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// `User-Agent` header sent on every request, including app version + platform.
    public static var userAgent: String {
        "WorkspaceTerminal/\(appVersion) (\(appBuild); iOS) CoderAPI/\(appVersion)"
    }
}
