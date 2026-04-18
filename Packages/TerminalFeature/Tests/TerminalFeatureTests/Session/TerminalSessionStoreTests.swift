import Foundation
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
}

private extension TerminalSession {
    /// Builds a session backed by a MockPTYTransport for unit tests.
    static func test() -> TerminalSession {
        // Using PTYTransport.MockPTYTransport directly avoids any real network.
        TerminalSession.makeForTesting()
    }
}
