import Foundation
import Testing
@testable import Auth

@Suite("InMemoryKeychainClient")
struct InMemoryKeychainClientTests {
    @Test("set then get returns the same data")
    func roundtrip() async throws {
        let kc = InMemoryKeychainClient()
        try await kc.set(key: "foo", value: Data("bar".utf8))
        let got = try await kc.get(key: "foo")
        #expect(got == Data("bar".utf8))
    }

    @Test("get on missing key returns nil")
    func getMissing() async throws {
        let kc = InMemoryKeychainClient()
        let got = try await kc.get(key: "absent")
        #expect(got == nil)
    }

    @Test("delete removes the key")
    func delete() async throws {
        let kc = InMemoryKeychainClient()
        try await kc.set(key: "foo", value: Data("bar".utf8))
        try await kc.delete(key: "foo")
        #expect(try await kc.get(key: "foo") == nil)
    }

    @Test("deleteAll clears everything")
    func deleteAll() async throws {
        let kc = InMemoryKeychainClient()
        try await kc.set(key: "a", value: Data("1".utf8))
        try await kc.set(key: "b", value: Data("2".utf8))
        try await kc.deleteAll()
        #expect(try await kc.get(key: "a") == nil)
        #expect(try await kc.get(key: "b") == nil)
    }
}
