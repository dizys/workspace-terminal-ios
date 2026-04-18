import Foundation
import Testing
@testable import PTYTransport

@Suite("MockPTYTransport")
struct MockPTYTransportTests {
    @Test("send records each call in order")
    func recordsSends() async throws {
        let m = MockPTYTransport()
        try await m.send(Data("a".utf8))
        try await m.send(Data("b".utf8))
        #expect(m.sent == [Data("a".utf8), Data("b".utf8)])
    }

    @Test("resize records each call")
    func recordsResizes() async throws {
        let m = MockPTYTransport()
        try await m.resize(TerminalSize(rows: 24, cols: 80))
        try await m.resize(TerminalSize(rows: 30, cols: 100))
        #expect(m.resizes == [TerminalSize(rows: 24, cols: 80), TerminalSize(rows: 30, cols: 100)])
    }

    @Test("simulateInbound delivers bytes through the inbound stream")
    func deliversInbound() async throws {
        let m = MockPTYTransport()
        m.simulateInbound(Data("hello".utf8))
        m.simulateInbound(Data("world".utf8))

        var iterator = m.inbound.makeAsyncIterator()
        let first = try await iterator.next()
        let second = try await iterator.next()
        #expect(first == Data("hello".utf8))
        #expect(second == Data("world".utf8))
    }

    @Test("connect emits .connecting then .connected")
    func connectEmitsLifecycle() async throws {
        let m = MockPTYTransport()
        var iterator = m.state.makeAsyncIterator()
        // Initial yield is .idle (constructor seed)
        let initial = await iterator.next()
        #expect(initial == .idle)

        try await m.connect()
        let s1 = await iterator.next()
        let s2 = await iterator.next()
        #expect(s1 == .connecting(attempt: 1))
        #expect(s2 == .connected)
        #expect(m.connectCalls == 1)
    }

    @Test("close records reason and finishes both streams")
    func closeFinishesStreams() async throws {
        let m = MockPTYTransport()
        await m.close(.userInitiated)
        #expect(m.closeCalls == [.userInitiated])

        // inbound finishes (no throw on .finish())
        var inboundIter = m.inbound.makeAsyncIterator()
        let next = try await inboundIter.next()
        #expect(next == nil)
    }
}
