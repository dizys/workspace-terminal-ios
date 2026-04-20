import CoderAPI
import Foundation
import Testing
@testable import PTYTransport

@Suite("LivePTYTransport — end-to-end against EchoPTYServer", .serialized)
struct LivePTYTransportTests {
    private func makeConfig() -> PTYTransportConfig {
        PTYTransportConfig(
            agentID: UUID(),
            reconnectToken: UUID(),
            initialSize: TerminalSize(rows: 24, cols: 80),
            command: "",
            reconnectPolicy: ReconnectPolicy(baseDelay: 0.01, maxDelay: 0.05, maxAttempts: 1, jitter: 1.0...1.0)
        )
    }

    @Test("happy path: connect → receive bytes → send keystroke (JSON envelope) → close 1000")
    func happyPath() async throws {
        let server = try EchoPTYServer()
        let serverURL = try await server.start()
        defer { server.stop() }

        // Strip the WS-specific path back to the host root. NWListener doesn't
        // path-match incoming connections — it accepts any path on its port —
        // so we can reuse it as a deployment baseURL even though the path
        // differs from what PTYURLBuilder produces.
        var rootComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        rootComponents.path = ""
        rootComponents.queryItems = nil
        let deployment = Deployment(baseURL: rootComponents.url!, displayName: "echo")

        // Server script: send greeting, expect a keystroke frame, then close normally.
        server.script([
            .send(Data("$ ".utf8)),
            .expectClientFrame { json in json.contains(#""data":"hi""#) },
            .close(code: 1000, reason: ""),
        ])

        let transport = LivePTYTransport(
            deployment: deployment,
            tls: .default,
            config: makeConfig(),
            tokenProvider: { SessionToken("test-token-XXXXXXXXXXXXXXXXXXXX") }
        )

        try await transport.connect()
        await server.waitForClient()

        // First inbound burst is the greeting.
        var iter = transport.inbound.makeAsyncIterator()
        let greeting = try await iter.next()
        #expect(greeting == Data("$ ".utf8))

        // Send a keystroke; server's predicate asserts the JSON envelope.
        try await transport.send(Data("hi".utf8))

        // After server closes 1000, inbound stream should finish (next() returns nil).
        // Allow a short window for the close frame to propagate.
        let final: Data?
        do {
            final = try await iter.next()
        } catch let PTYError.closed(reason) {
            // 1000 → .userInitiated classification (server-initiated normal close).
            #expect(reason == .userInitiated)
            return
        }
        #expect(final == nil)
    }

    @Test("transient close (1001 ping failed) → auto-reconnect with same UUID; replay flows continuously")
    func reconnectsOnTransientClose() async throws {
        let server = try EchoPTYServer()
        let serverURL = try await server.start()
        defer { server.stop() }

        var rootComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        rootComponents.path = ""
        rootComponents.queryItems = nil
        let deployment = Deployment(baseURL: rootComponents.url!, displayName: "echo")

        // Per-connection scripts. First connection sends FIRST then closes 1001;
        // reconnect should yield connection #2 which sends SECOND then closes 1000.
        server.scripts([
            [.send(Data("FIRST".utf8)), .close(code: 1001, reason: "Ping failed")],
            [.send(Data("SECOND".utf8)), .close(code: 1000, reason: "")],
        ])

        let transport = LivePTYTransport(
            deployment: deployment,
            tls: .default,
            config: PTYTransportConfig(
                agentID: UUID(),
                reconnectToken: UUID(),
                initialSize: TerminalSize(rows: 24, cols: 80),
                command: "",
                reconnectPolicy: ReconnectPolicy(
                    baseDelay: 0.01, maxDelay: 0.05, maxAttempts: 3, jitter: 1.0...1.0
                )
            ),
            tokenProvider: { SessionToken("test-token-XXXXXXXXXXXXXXXXXXXX") }
        )

        try await transport.connect()
        var iter = transport.inbound.makeAsyncIterator()

        let first = try await iter.next()
        #expect(first == Data("FIRST".utf8))

        // Reconnect happens transparently; SECOND arrives without an intervening
        // throw or stream-finish.
        let second = try await iter.next()
        #expect(second == Data("SECOND".utf8))
    }

    @Test("connect() collapses pending reconnect backoff and reconnects immediately")
    func connectCollapsesPendingReconnectBackoff() async throws {
        let server = try EchoPTYServer()
        let serverURL = try await server.start()
        defer { server.stop() }

        var rootComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        rootComponents.path = ""
        rootComponents.queryItems = nil
        let deployment = Deployment(baseURL: rootComponents.url!, displayName: "echo")

        server.scripts([
            [.send(Data("FIRST".utf8)), .close(code: 1001, reason: "Ping failed")],
            [.send(Data("SECOND".utf8)), .close(code: 1000, reason: "")],
        ])

        let transport = LivePTYTransport(
            deployment: deployment,
            tls: .default,
            config: PTYTransportConfig(
                agentID: UUID(),
                reconnectToken: UUID(),
                initialSize: TerminalSize(rows: 24, cols: 80),
                command: "",
                reconnectPolicy: ReconnectPolicy(
                    baseDelay: 30, maxDelay: 30, maxAttempts: 3, jitter: 1.0...1.0
                )
            ),
            tokenProvider: { SessionToken("test-token-XXXXXXXXXXXXXXXXXXXX") }
        )

        try await transport.connect()
        var inbound = transport.inbound.makeAsyncIterator()
        #expect(try await inbound.next() == Data("FIRST".utf8))
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(server.recordingSnapshot().connectionCount == 1)

        try await transport.connect()
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(server.recordingSnapshot().connectionCount == 2)
    }

    @Test("foreground recovery collapses pending reconnect backoff")
    func foregroundRecoveryCollapsesPendingReconnectBackoff() async throws {
        let server = try EchoPTYServer()
        let serverURL = try await server.start()
        defer { server.stop() }

        var rootComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        rootComponents.path = ""
        rootComponents.queryItems = nil
        let deployment = Deployment(baseURL: rootComponents.url!, displayName: "echo")

        server.scripts([
            [.send(Data("FIRST".utf8)), .close(code: 1001, reason: "Ping failed")],
            [.send(Data("SECOND".utf8)), .close(code: 1000, reason: "")],
        ])

        let transport = LivePTYTransport(
            deployment: deployment,
            tls: .default,
            config: PTYTransportConfig(
                agentID: UUID(),
                reconnectToken: UUID(),
                initialSize: TerminalSize(rows: 24, cols: 80),
                command: "",
                reconnectPolicy: ReconnectPolicy(
                    baseDelay: 30, maxDelay: 30, maxAttempts: 3, jitter: 1.0...1.0
                )
            ),
            tokenProvider: { SessionToken("test-token-XXXXXXXXXXXXXXXXXXXX") }
        )

        try await transport.connect()
        var inbound = transport.inbound.makeAsyncIterator()
        #expect(try await inbound.next() == Data("FIRST".utf8))
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(server.recordingSnapshot().connectionCount == 1)

        await transport.checkAndReconnectIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(server.recordingSnapshot().connectionCount == 2)
    }

    @Test("agent unreachable (1011 dial …) → no reconnect; stream finishes with .agentUnreachable")
    func doesNotReconnectOnAgentUnreachable() async throws {
        let server = try EchoPTYServer()
        let serverURL = try await server.start()
        defer { server.stop() }

        var rootComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        rootComponents.path = ""
        rootComponents.queryItems = nil
        let deployment = Deployment(baseURL: rootComponents.url!, displayName: "echo")

        // Only ONE script — if the transport tried to reconnect, server has
        // nothing to deliver and the test would hang or behave unexpectedly.
        server.scripts([
            [.close(code: 1011, reason: "dial workspace agent: tailnet unreachable")],
        ])

        let transport = LivePTYTransport(
            deployment: deployment,
            tls: .default,
            config: PTYTransportConfig(
                agentID: UUID(),
                reconnectToken: UUID(),
                initialSize: TerminalSize(rows: 24, cols: 80),
                command: "",
                reconnectPolicy: ReconnectPolicy(
                    baseDelay: 0.01, maxDelay: 0.05, maxAttempts: 3, jitter: 1.0...1.0
                )
            ),
            tokenProvider: { SessionToken("test-token-XXXXXXXXXXXXXXXXXXXX") }
        )

        try await transport.connect()

        // Inbound stream should throw PTYError.closed(.agentUnreachable(...))
        var iter = transport.inbound.makeAsyncIterator()
        do {
            while try await iter.next() != nil {} // drain until throw
            Issue.record("Expected PTYError.closed(.agentUnreachable), but stream finished cleanly")
        } catch let PTYError.closed(reason) {
            if case .agentUnreachable = reason {
                // success
            } else {
                Issue.record("Expected .agentUnreachable, got \(reason)")
            }
        }
    }
}
