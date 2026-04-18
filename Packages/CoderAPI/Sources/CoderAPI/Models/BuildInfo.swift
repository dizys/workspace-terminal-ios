import Foundation

/// Coder server build info. Mirrors `GET /api/v2/buildinfo`.
///
/// Notably contains `appHostname`, which determines whether the deployment
/// supports subdomain-style port forwarding (M3.5 — see ADR-0010).
public struct BuildInfo: Sendable, Hashable, Codable {
    public let externalURL: URL
    public let version: String
    public let dashboardURL: URL?
    public let workspaceProxy: Bool
    public let agentAPIVersion: String?
    public let upgradeMessage: String?
    public let deploymentID: String?
    public let appHostname: String?

    public init(
        externalURL: URL,
        version: String,
        dashboardURL: URL? = nil,
        workspaceProxy: Bool = false,
        agentAPIVersion: String? = nil,
        upgradeMessage: String? = nil,
        deploymentID: String? = nil,
        appHostname: String? = nil
    ) {
        self.externalURL = externalURL
        self.version = version
        self.dashboardURL = dashboardURL
        self.workspaceProxy = workspaceProxy
        self.agentAPIVersion = agentAPIVersion
        self.upgradeMessage = upgradeMessage
        self.deploymentID = deploymentID
        self.appHostname = appHostname
    }

    enum CodingKeys: String, CodingKey {
        case externalURL = "external_url"
        case version
        case dashboardURL = "dashboard_url"
        case workspaceProxy = "workspace_proxy"
        case agentAPIVersion = "agent_api_version"
        case upgradeMessage = "upgrade_message"
        case deploymentID = "deployment_id"
        case appHostname = "app_hostname"
    }

    // Defensive decode — Coder may return URL fields as empty strings.
    // externalURL is required: fall back to a sentinel if missing/empty so
    // a single weird BuildInfo doesn't fail the whole probe.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let externalRaw = try container.decodeIfPresent(String.self, forKey: .externalURL) ?? ""
        self.externalURL = URL(string: externalRaw) ?? URL(string: "https://invalid.invalid")!
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "unknown"
        self.dashboardURL = try LenientURL.decode(from: container, forKey: .dashboardURL)
        self.workspaceProxy = try container.decodeIfPresent(Bool.self, forKey: .workspaceProxy) ?? false
        self.agentAPIVersion = try container.decodeIfPresent(String.self, forKey: .agentAPIVersion)
        self.upgradeMessage = try container.decodeIfPresent(String.self, forKey: .upgradeMessage)
        self.deploymentID = try container.decodeIfPresent(String.self, forKey: .deploymentID)
        let hostnameRaw = try container.decodeIfPresent(String.self, forKey: .appHostname)
        self.appHostname = (hostnameRaw?.isEmpty == false) ? hostnameRaw : nil
    }
}
