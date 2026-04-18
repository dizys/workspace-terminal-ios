import CoderAPI
import Foundation
import PTYTransport

/// One terminal session — a thin actor over a single `PTYTransport`. The
/// reducer subscribes to `state` for connection-phase changes; the
/// `WTTerminalView` subscribes to `inbound` directly to feed SwiftTerm
/// without round-tripping every byte through the TCA action loop (per
/// `docs/performance.md` — action-storm avoidance).
public final class TerminalSession: @unchecked Sendable {
    public let id: UUID
    public let agent: WorkspaceAgent
    public let transport: any PTYTransport

    public init(id: UUID, agent: WorkspaceAgent, transport: any PTYTransport) {
        self.id = id
        self.agent = agent
        self.transport = transport
    }

    public var inbound: AsyncThrowingStream<Data, Error> { transport.inbound }
    public var state: AsyncStream<ConnectionState> { transport.state }

    public func connect() async throws { try await transport.connect() }
    public func send(_ bytes: Data) async throws { try await transport.send(bytes) }
    public func resize(_ size: TerminalSize) async throws { try await transport.resize(size) }
    public func close(_ reason: CloseReason = .userInitiated) async { await transport.close(reason) }
}

extension TerminalSession {
    /// Test factory — wraps a `MockPTYTransport` so reducer/store tests need
    /// no real network. Visible only to test targets via `@testable import`.
    static func makeForTesting() -> TerminalSession {
        TerminalSession(
            id: UUID(),
            agent: .stub(),
            transport: MockPTYTransport()
        )
    }
}

private extension WorkspaceAgent {
    static func stub() -> WorkspaceAgent {
        WorkspaceAgent(
            id: UUID(),
            name: "stub",
            status: .connected,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
