import Foundation

extension LiveCoderAPIClient {
    public func fetchBuildInfo() async throws -> BuildInfo {
        try await http.send(HTTPRequest(
            method: .get,
            path: "/buildinfo",
            requiresAuth: false
        ))
    }
}
