import Foundation

/// Map raw WebSocket close codes / pre-upgrade HTTP statuses to a typed
/// `CloseReason`. Pure function; trivially testable.
///
/// Source-of-truth for the codes:
///   `.refs/coder/coderd/workspaceapps/proxy.go:776,789`
///   `.refs/coder/coderd/httpapi/websocket.go:53`
enum CloseClassifier {
    static func classify(code: Int, reason: String) -> CloseReason {
        switch code {
        case 1000:
            return .userInitiated
        case 1001:
            // "Going away" — server is shutting the connection because we
            // missed pings (typically because iOS suspended the URLSession
            // WebSocket task in the background). Always reconnectable; the
            // Coder server keeps the reconnecting-PTY ring buffer for ~5min.
            return .serverTimeout
        case 1011:
            // Coder's PTY handler emits two distinct dial-failure messages,
            // both meaning "agent not reachable from coderd."
            if reason.lowercased().hasPrefix("dial") {
                return .agentUnreachable(detail: reason)
            }
            return .fatal(code: code, reason: reason)
        default:
            return .fatal(code: code, reason: reason)
        }
    }

    /// Pre-upgrade HTTP status (the WS upgrade itself failed).
    static func classifyHTTPHandshake(status: Int) -> CloseReason {
        switch status {
        case 401, 403:
            return .authExpired
        default:
            return .fatal(code: status, reason: "HTTP \(status)")
        }
    }
}
