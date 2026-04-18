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
}
