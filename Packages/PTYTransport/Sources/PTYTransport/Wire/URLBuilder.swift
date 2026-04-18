import CoderAPI
import Foundation

/// Construct the WebSocket URL for the PTY endpoint.
///
/// Param order matches the upstream Go CLI exactly so that any future tooling
/// (HAR captures, server logs) compares cleanly:
///   `.refs/coder/cli/exp_rpty.go:154-188`
///   `.refs/coder/codersdk/workspacesdk/workspacesdk.go:341-363`
///
/// `command` is always present, even when empty. Optional devcontainer params
/// (`container`, `container_user`, `backend_type`) are appended only when set.
enum PTYURLBuilder {
    static func makeURL(deployment: Deployment, config: PTYTransportConfig) -> URL {
        let base = deployment.apiURL(path: "/workspaceagents/\(config.agentID.uuidString.lowercased())/pty")
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            preconditionFailure("Failed to build URLComponents for \(base)")
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "reconnect", value: config.reconnectToken.uuidString.lowercased()),
            URLQueryItem(name: "width", value: String(config.initialSize.cols)),
            URLQueryItem(name: "height", value: String(config.initialSize.rows)),
            URLQueryItem(name: "command", value: config.command),
        ]
        if let v = config.container       { items.append(URLQueryItem(name: "container", value: v)) }
        if let v = config.containerUser   { items.append(URLQueryItem(name: "container_user", value: v)) }
        if let v = config.backendType     { items.append(URLQueryItem(name: "backend_type", value: v.rawValue)) }
        components.queryItems = items

        switch components.scheme?.lowercased() {
        case "https": components.scheme = "wss"
        case "http":  components.scheme = "ws"
        default:      break
        }

        guard let url = components.url else {
            preconditionFailure("Failed to build PTY URL from components: \(components)")
        }
        return url
    }
}
