import Foundation

extension LiveCoderAPIClient {
    public func listMyWorkspaces() async throws -> [Workspace] {
        let response: WorkspacesResponse = try await http.send(HTTPRequest(
            method: .get,
            path: "/workspaces",
            query: [URLQueryItem(name: "q", value: "owner:me")]
        ))
        return response.workspaces
    }

    public func fetchWorkspace(id: UUID) async throws -> Workspace {
        try await http.send(HTTPRequest(
            method: .get,
            path: "/workspaces/\(id.uuidString.lowercased())"
        ))
    }
}
