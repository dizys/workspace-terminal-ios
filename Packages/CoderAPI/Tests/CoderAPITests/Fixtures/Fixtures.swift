import Foundation
@testable import CoderAPI

enum Fixtures {
    static let deployment = Deployment(
        baseURL: URL(string: "https://coder.example.com")!,
        displayName: "Example",
        username: "alice"
    )

    static let userAgent = "WorkspaceTerminal/0.1.0 (1; iOS) CoderAPI/0.1.0"

    static func client(token: SessionToken? = "test-token") -> LiveCoderAPIClient {
        LiveCoderAPIClient(
            deployment: deployment,
            userAgent: userAgent,
            session: URLSession.stubbed(),
            tokenProvider: { token }
        )
    }

    static func json(_ string: String) -> Data {
        Data(string.utf8)
    }
}
