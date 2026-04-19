import CoderAPI
import Foundation
import os.lock
import PTYTransport
#if canImport(UIKit)
import UIKit
#endif

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

    /// State protected by an unfair lock (async-context-safe; we never hold
    /// it across `await`).
    private struct LockedState {
        var subscribers: [UUID: AsyncStream<Data>.Continuation] = [:]
        /// Ring buffer of recent PTY bytes — replayed to any new subscriber so
        /// re-mounting the terminal view (e.g. after navigating back) shows
        /// the existing scrollback instead of starting blank. 64 KiB matches
        /// Coder's own server-side reconnecting-PTY buffer.
        var scrollback = Data()
    }
    private static let scrollbackCap = 64 * 1024
    private let locked = OSAllocatedUnfairLock<LockedState>(initialState: LockedState())
    private var pumpTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?

    public init(id: UUID, agent: WorkspaceAgent, transport: any PTYTransport) {
        self.id = id
        self.agent = agent
        self.transport = transport
        startPump()
        observeForeground()
    }

    deinit {
        pumpTask?.cancel()
        foregroundObserver.map { NotificationCenter.default.removeObserver($0) }
    }

    /// Returns a fresh `AsyncStream<Data>`. Multiple subscribers may exist
    /// concurrently; each receives a copy of every chunk yielded after it
    /// subscribes. Streams finish when the underlying pump finishes.
    public var inbound: AsyncStream<Data> {
        let key = UUID()
        return AsyncStream { continuation in
            // Replay scrollback to the new subscriber so the rendered terminal
            // shows the same content it would have if it had been alive the
            // whole time (e.g. user navigated back, then re-opened the agent).
            let replay: Data = locked.withLock { state in
                state.subscribers[key] = continuation
                return state.scrollback
            }
            if !replay.isEmpty {
                continuation.yield(replay)
            }
            continuation.onTermination = { [weak self] _ in
                self?.locked.withLock { $0.subscribers.removeValue(forKey: key) }
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
                self?.finishAllSubscribers()
                return
            }
            self?.finishAllSubscribers()
        }
    }

    private func broadcast(_ chunk: Data) {
        let conts: [AsyncStream<Data>.Continuation] = locked.withLock { state in
            // Append to scrollback ring buffer, dropping oldest bytes once we
            // exceed the cap.
            state.scrollback.append(chunk)
            if state.scrollback.count > Self.scrollbackCap {
                state.scrollback.removeFirst(state.scrollback.count - Self.scrollbackCap)
            }
            return Array(state.subscribers.values)
        }
        for cont in conts { cont.yield(chunk) }
    }

    private func finishAllSubscribers() {
        let conts: [AsyncStream<Data>.Continuation] = locked.withLock { state in
            let conts = Array(state.subscribers.values)
            state.subscribers.removeAll()
            return conts
        }
        for cont in conts { cont.finish() }
    }

    /// On app foreground, proactively check if the WS is still alive.
    /// iOS suspends WebSocket tasks in the background; the server closes
    /// after 15s of missed pings. Without this, the receive loop stays
    /// suspended and the user sees a frozen terminal until the system
    /// resumes the Task (which may never happen cleanly).
    private func observeForeground() {
        #if canImport(UIKit)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.transport.checkAndReconnectIfNeeded()
            }
        }
        #endif
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
