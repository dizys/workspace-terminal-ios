import Foundation

/// Why the WebSocket terminated. The transport classifies raw WS close codes
/// (and pre-upgrade HTTP statuses) into one of these cases so callers don't
/// have to interpret protocol details.
///
/// Close codes mapped here come from the server source:
///   `.refs/coder/coderd/workspaceapps/proxy.go:776,789` — 1011 dial failures
///   `.refs/coder/coderd/httpapi/websocket.go:53`        — 1001 ping timeout
public enum CloseReason: Sendable, Equatable {
    /// We initiated a graceful close — sent WS code 1000.
    case userInitiated
    /// Server emitted 1011 with a "dial..." reason — workspace stopped, agent
    /// crashed, or otherwise unreachable. Transport stops auto-reconnect; UI
    /// should offer manual retry.
    case agentUnreachable(detail: String)
    /// Pre-upgrade HTTP 401 — token expired or revoked. Caller refreshes auth.
    case authExpired
    /// Server pinged us and we (or the network) didn't respond — 1001.
    /// Transient; transport reconnects.
    case serverTimeout
    /// Anything else — we report and don't retry.
    case fatal(code: Int, reason: String)
}
