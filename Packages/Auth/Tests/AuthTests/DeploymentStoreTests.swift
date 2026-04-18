import CoderAPI
import Foundation
import Testing
@testable import Auth

@Suite("LiveDeploymentStore")
struct LiveDeploymentStoreTests {
    private func makeStored(displayName: String = "ex") -> StoredDeployment {
        StoredDeployment(
            deployment: Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: displayName),
            token: SessionToken("tok-\(UUID().uuidString.prefix(8))")
        )
    }

    @Test("Empty store has no active deployment")
    func emptyStore() async throws {
        let store = LiveDeploymentStore(keychain: InMemoryKeychainClient())
        #expect(try await store.activeDeployment() == nil)
        #expect(try await store.allDeployments().isEmpty)
    }

    @Test("upsertActive adds and marks active")
    func upsertActive() async throws {
        let store = LiveDeploymentStore(keychain: InMemoryKeychainClient())
        let stored = makeStored()
        try await store.upsertActive(stored)
        #expect(try await store.activeDeployment()?.id == stored.id)
        #expect(try await store.allDeployments().count == 1)
    }

    @Test("upsertActive updates an existing entry")
    func upsertExisting() async throws {
        let store = LiveDeploymentStore(keychain: InMemoryKeychainClient())
        var stored = makeStored()
        try await store.upsertActive(stored)
        stored.token = SessionToken("rotated")
        try await store.upsertActive(stored)
        #expect(try await store.activeDeployment()?.token.value == "rotated")
        #expect(try await store.allDeployments().count == 1)
    }

    @Test("switchActive flips the active id")
    func switchActive() async throws {
        let store = LiveDeploymentStore(keychain: InMemoryKeychainClient())
        let a = makeStored(displayName: "a")
        let b = makeStored(displayName: "b")
        try await store.upsertActive(a)
        try await store.upsertActive(b)
        try await store.switchActive(to: a.id)
        #expect(try await store.activeDeployment()?.id == a.id)
    }

    @Test("switchActive throws notFound for unknown id")
    func switchActiveUnknown() async throws {
        let store = LiveDeploymentStore(keychain: InMemoryKeychainClient())
        let unknown = UUID()
        await #expect(throws: DeploymentStoreError.notFound(unknown)) {
            try await store.switchActive(to: unknown)
        }
    }

    @Test("remove drops the entry; if active, picks the most recent remaining")
    func removeActive() async throws {
        let store = LiveDeploymentStore(keychain: InMemoryKeychainClient())
        let a = makeStored(displayName: "a")
        let b = makeStored(displayName: "b")
        try await store.upsertActive(a)
        try await store.upsertActive(b)
        try await store.remove(id: b.id)
        #expect(try await store.activeDeployment()?.id == a.id)
    }

    @Test("updateToken rotates the token")
    func updateToken() async throws {
        let store = LiveDeploymentStore(keychain: InMemoryKeychainClient())
        let stored = makeStored()
        try await store.upsertActive(stored)
        try await store.updateToken(deploymentID: stored.id, token: SessionToken("new"))
        #expect(try await store.activeDeployment()?.token.value == "new")
    }

    @Test("reset wipes everything")
    func reset() async throws {
        let store = LiveDeploymentStore(keychain: InMemoryKeychainClient())
        try await store.upsertActive(makeStored())
        try await store.reset()
        #expect(try await store.activeDeployment() == nil)
    }
}
