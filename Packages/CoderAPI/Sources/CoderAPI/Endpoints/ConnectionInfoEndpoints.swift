import Foundation

extension LiveCoderAPIClient {
    /// `GET /api/v2/workspaceagents/{id}/connection`
    ///
    /// Returns DERP map + connection config needed to establish a tailnet
    /// tunnel to the agent.
    ///
    /// Source: `.refs/coder/codersdk/workspacesdk/workspacesdk.go:164`
    public func agentConnectionInfo(agentID: UUID) async throws -> AgentConnectionInfo {
        try await http.send(HTTPRequest(
            method: .get,
            path: "/workspaceagents/\(agentID.uuidString.lowercased())/connection"
        ))
    }
}
