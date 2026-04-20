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

    @Test("TerminalSession suppresses duplicate server replay after reconnect")
    func sessionSuppressesDuplicateReconnectReplay() async throws {
        let transport = MockPTYTransport()
        let session = TerminalSession(id: UUID(), agent: .testAgent, transport: transport)
        let received = ReceivedChunks()
        let history = Data("coder$ echo haha\r\nhaha\r\ncoder$ ".utf8)
        let fresh = Data("echo fresh\r\nfresh\r\ncoder$ ".utf8)

        let consumeTask = Task {
            for await chunk in session.inbound {
                await received.append(chunk)
            }
        }
        defer {
            consumeTask.cancel()
            Task { await session.close(.userInitiated) }
        }

        transport.simulateInbound(history)
        #expect(await eventually { await received.snapshot() == [history] })

        transport.simulateState(.reconnecting(attempt: 2, lastError: nil))
        try await Task.sleep(nanoseconds: 50_000_000)
        transport.simulateInbound(history)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await received.snapshot() == [history])

        transport.simulateInbound(fresh)
        #expect(await eventually { await received.snapshot() == [history, fresh] })
    }

    @Test("TerminalSession allows new bytes after a partial reconnect replay")
    func sessionAllowsNewBytesAfterPartialReconnectReplay() async throws {
        let transport = MockPTYTransport()
        let session = TerminalSession(id: UUID(), agent: .testAgent, transport: transport)
        let received = ReceivedChunks()
        let history = Data("history".utf8)
        let replayWithNewBytes = Data("historynew".utf8)
        let newBytes = Data("new".utf8)

        let consumeTask = Task {
            for await chunk in session.inbound {
                await received.append(chunk)
            }
        }
        defer {
            consumeTask.cancel()
            Task { await session.close(.userInitiated) }
        }

        transport.simulateInbound(history)
        #expect(await eventually { await received.snapshot() == [history] })

        transport.simulateState(.reconnecting(attempt: 2, lastError: nil))
        try await Task.sleep(nanoseconds: 50_000_000)
        transport.simulateInbound(replayWithNewBytes)
        #expect(await eventually { await received.snapshot() == [history, newBytes] })
    }
}

private actor ReceivedChunks {
    private var chunks: [Data] = []

    func append(_ chunk: Data) {
        chunks.append(chunk)
    }

    func snapshot() -> [Data] {
        chunks
    }
}

private func eventually(
    timeoutNanoseconds: UInt64 = 500_000_000,
    condition: @escaping () async -> Bool
) async -> Bool {
    let interval: UInt64 = 25_000_000
    let attempts = max(1, Int(timeoutNanoseconds / interval))
    for _ in 0..<attempts {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: interval)
    }
    return await condition()
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
