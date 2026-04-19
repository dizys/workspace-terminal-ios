import Foundation

extension LiveCoderAPIClient {
    /// `GET /api/v2/workspaceagents/{id}/listening-ports`
    ///
    /// Source: `.refs/coder/codersdk/workspaceagents.go:402`
    public func listListeningPorts(agentID: UUID) async throws -> [ListeningPort] {
        let response: ListeningPortsResponse = try await http.send(HTTPRequest(
            method: .get,
            path: "/workspaceagents/\(agentID.uuidString.lowercased())/listening-ports"
        ))
        return response.ports
    }

    /// `GET /api/v2/applications/host`
    ///
    /// Returns the wildcard app hostname (e.g. `"*--apps.coder.example.com"`)
    /// or nil if not configured.
    ///
    /// Source: `.refs/coder/codersdk/deployment.go:4569`
    public func appHost() async throws -> String? {
        struct AppHostResponse: Codable {
            let host: String
        }
        let response: AppHostResponse = try await http.send(HTTPRequest(
            method: .get,
            path: "/applications/host"
        ))
        return response.host.isEmpty ? nil : response.host
    }
}
