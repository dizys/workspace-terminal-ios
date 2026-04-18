import CoderAPI
import Foundation
import PTYTransport

/// One terminal session — a thin actor over a single `PTYTransport`.
///
/// `inbound` is a **multicaster**: each call returns a fresh `AsyncStream<Data>`
/// that receives bytes as they arrive. Internally, the session iterates the
/// underlying `transport.inbound` exactly once and fans out to every active
/// subscriber. This is required because `AsyncThrowingStream` is single-consumer
/// by contract — a SwiftUI re-mount of `WTTerminalView` (e.g. when adding a
/// terminal tab) would otherwise spin up a second iterator on the same stream
/// and crash with `attempt to await next() on more than one task`.
public final class TerminalSession: @unchecked Sendable {
    public let id: UUID
    public let agent: WorkspaceAgent
    public let transport: any PTYTransport

    private let lock = NSLock()
    private var subscribers: [UUID: AsyncStream<Data>.Continuation] = [:]
    private var pumpTask: Task<Void, Never>?
    private var pumpError: Error?

    public init(id: UUID, agent: WorkspaceAgent, transport: any PTYTransport) {
        self.id = id
        self.agent = agent
        self.transport = transport
        startPump()
    }

    deinit {
        pumpTask?.cancel()
    }

    /// Returns a fresh `AsyncStream<Data>`. Multiple subscribers may exist
    /// concurrently; each receives a copy of every chunk yielded after it
    /// subscribes. Streams finish when the underlying pump finishes.
    public var inbound: AsyncStream<Data> {
        let key = UUID()
        return AsyncStream { continuation in
            lock.lock()
            subscribers[key] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.subscribers.removeValue(forKey: key)
                self?.lock.unlock()
            }
        }
    }

    public var state: AsyncStream<ConnectionState> { transport.state }

    public func connect() async throws { try await transport.connect() }
    public func send(_ bytes: Data) async throws { try await transport.send(bytes) }
    public func resize(_ size: TerminalSize) async throws { try await transport.resize(size) }
    public func close(_ reason: CloseReason = .userInitiated) async {
        await transport.close(reason)
        pumpTask?.cancel()
    }

    private func startPump() {
        let upstream = transport.inbound
        pumpTask = Task { [weak self] in
            do {
                for try await chunk in upstream {
                    if Task.isCancelled { return }
                    self?.broadcast(chunk)
                }
            } catch {
                self?.lock.lock()
                self?.pumpError = error
                let conts = self?.subscribers.values.map { $0 } ?? []
                self?.subscribers.removeAll()
                self?.lock.unlock()
                for cont in conts { cont.finish() }
                return
            }
            self?.lock.lock()
            let conts = self?.subscribers.values.map { $0 } ?? []
            self?.subscribers.removeAll()
            self?.lock.unlock()
            for cont in conts { cont.finish() }
        }
    }

    private func broadcast(_ chunk: Data) {
        lock.lock()
        let conts = Array(subscribers.values)
        lock.unlock()
        for cont in conts { cont.yield(chunk) }
    }
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
