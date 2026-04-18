import Testing
@testable import CoderAPI
import Foundation

@Suite("CoderAPI smoke")
struct CoderAPITests {
    @Test("Version is set")
    func versionIsSet() {
        #expect(!CoderAPI.version.isEmpty)
    }

    @Test("Deployment encodes and decodes")
    func deploymentRoundtrip() throws {
        let deployment = Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: "Example")
        let data = try JSONEncoder().encode(deployment)
        let decoded = try JSONDecoder().decode(Deployment.self, from: data)
        #expect(decoded == deployment)
    }
}
