import Foundation
import Testing
@testable import CoderAPI

@Suite("Deployment")
struct DeploymentTests {
    @Test("apiURL builds /api/v2 path correctly when baseURL has no trailing slash")
    func apiURLNoTrailingSlash() {
        let dep = Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: "x")
        #expect(dep.apiURL(path: "/users/me").absoluteString == "https://coder.example.com/api/v2/users/me")
    }

    @Test("apiURL handles a baseURL with a trailing slash")
    func apiURLTrailingSlash() {
        let dep = Deployment(baseURL: URL(string: "https://coder.example.com/")!, displayName: "x")
        #expect(dep.apiURL(path: "/users/me").absoluteString == "https://coder.example.com/api/v2/users/me")
    }

    @Test("apiURL handles a baseURL with a path prefix (subpath deployment)")
    func apiURLWithSubpath() {
        let dep = Deployment(baseURL: URL(string: "https://corp.com/coder")!, displayName: "x")
        #expect(dep.apiURL(path: "users/me").absoluteString == "https://corp.com/coder/api/v2/users/me")
    }

    @Test("Deployment encodes and decodes")
    func roundtrip() throws {
        let dep = Fixtures.deployment
        let data = try JSONEncoder().encode(dep)
        let decoded = try JSONDecoder().decode(Deployment.self, from: data)
        #expect(decoded == dep)
    }
}
