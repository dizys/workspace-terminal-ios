import Foundation

/// Configuration for one logical PTY session.
///
/// `reconnectToken` is owned by the caller (typically `TerminalFeature`) and
/// must remain stable for the life of the terminal tab — it is what lets the
/// server replay the ring buffer after a network blip.
///
/// `command` is always sent (even as empty string) to match the CLI behavior
/// (`.refs/coder/cli/exp_rpty.go:154-188`). Empty means "open the workspace's
/// default shell."
///
/// `container` / `containerUser` target a devcontainer sub-agent inside the
/// workspace (`.refs/coder/coderd/workspaceapps/proxy.go:736-743`).
public struct PTYTransportConfig: Sendable, Equatable {
    public let agentID: UUID
    public let reconnectToken: UUID
    public let initialSize: TerminalSize
    public let command: String
    public let container: String?
    public let containerUser: String?
    public let backendType: BackendType?
    public let reconnectPolicy: ReconnectPolicy

    public init(
        agentID: UUID,
        reconnectToken: UUID,
        initialSize: TerminalSize,
        command: String = "",
        container: String? = nil,
        containerUser: String? = nil,
        backendType: BackendType? = nil,
        reconnectPolicy: ReconnectPolicy = .default
    ) {
        self.agentID = agentID
        self.reconnectToken = reconnectToken
        self.initialSize = initialSize
        self.command = command
        self.container = container
        self.containerUser = containerUser
        self.backendType = backendType
        self.reconnectPolicy = reconnectPolicy
    }
}
