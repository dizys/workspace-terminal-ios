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
}
