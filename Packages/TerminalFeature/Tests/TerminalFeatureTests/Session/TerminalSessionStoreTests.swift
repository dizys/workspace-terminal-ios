import CoderAPI
import Foundation
import PTYTransport
import Testing
@testable import TerminalFeature

@Suite("TerminalSessionStore")
struct TerminalSessionStoreTests {
    @Test("attach makes the session retrievable by id")
    func attachAndRetrieve() async {
        let store = TerminalSessionStore()
        let id = UUID()
        let session = TerminalSession.test()
        await store.attach(id: id, session: session)

        let retrieved = await store.session(for: id)
        #expect(retrieved === session)
    }

    @Test("session(for:) returns nil for unknown id")
    func unknownIdReturnsNil() async {
        let store = TerminalSessionStore()
        let retrieved = await store.session(for: UUID())
        #expect(retrieved == nil)
    }

    @Test("detach removes the session")
    func detachRemoves() async {
        let store = TerminalSessionStore()
        let id = UUID()
        let session = TerminalSession.test()
        await store.attach(id: id, session: session)
        await store.detach(id: id)

        let retrieved = await store.session(for: id)
        #expect(retrieved == nil)
    }

    @Test("attaching a second session under the same id replaces the first")
    func attachReplacesUnderSameID() async {
        let store = TerminalSessionStore()
        let id = UUID()
        let first = TerminalSession.test()
        let second = TerminalSession.test()
        await store.attach(id: id, session: first)
        await store.attach(id: id, session: second)

        let retrieved = await store.session(for: id)
        #expect(retrieved === second)
    }

    @Test("TerminalSession state stream replays latest state to new subscribers")
    func sessionStateReplaysLatestToNewSubscribers() async throws {
        let transport = MockPTYTransport()
        let session = TerminalSession(id: UUID(), agent: .testAgent, transport: transport)
        defer {
            Task { await session.close(.userInitiated) }
        }

        var first = session.state.makeAsyncIterator()
        #expect(await first.next() == .idle)

        transport.simulateState(.connected)
        try await Task.sleep(nanoseconds: 50_000_000)

        var second = session.state.makeAsyncIterator()
        #expect(await second.next() == .connected)
    }
}

private extension TerminalSession {
    /// Builds a session backed by a MockPTYTransport for unit tests.
    static func test() -> TerminalSession {
        // Using PTYTransport.MockPTYTransport directly avoids any real network.
        TerminalSession.makeForTesting()
    }
}

private extension WorkspaceAgent {
    static let testAgent = WorkspaceAgent(
        id: UUID(),
        name: "test",
        status: .connected,
        createdAt: Date(),
        updatedAt: Date()
    )
}
