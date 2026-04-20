import Foundation
@testable import CoderAPI

enum Fixtures {
    static let deployment = Deployment(
        baseURL: URL(string: "https://coder.example.com")!,
        displayName: "Example",
        username: "alice"
    )

    static let userAgent = "WorkspaceTerminal/0.0.0 (0; iOS) CoderAPI/0.0.0"

    /// Build a `LiveCoderAPIClient` for tests, optionally with a stubbed
    /// session (for endpoint tests). Pass nothing for tests that don't hit
    /// the network.
    static func client(
        token: SessionToken? = "test-token",
        session: URLSession? = nil
    ) -> LiveCoderAPIClient {
        if let session {
            return LiveCoderAPIClient(
                deployment: deployment,
                userAgent: userAgent,
                session: session,
                tokenProvider: { token }
            )
        }
        return LiveCoderAPIClient(
            deployment: deployment,
            userAgent: userAgent,
            tokenProvider: { token }
        )
    }

    static func json(_ string: String) -> Data {
        Data(string.utf8)
    }
}
