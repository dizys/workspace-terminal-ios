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
        var stateSubscribers: [UUID: AsyncStream<ConnectionState>.Continuation] = [:]
        var latestConnectionState: ConnectionState = .idle
        var replayDeduper: ReplayDeduper?
        /// Ring buffer of recent PTY bytes — replayed to any new subscriber so
        /// re-mounting the terminal view (e.g. after navigating back) shows
        /// the existing scrollback instead of starting blank. 64 KiB matches
        /// Coder's own server-side reconnecting-PTY buffer.
        var scrollback = Data()

        mutating func removeReconnectReplayDuplicate(from chunk: Data) -> Data {
            guard var deduper = replayDeduper else { return chunk }
            let filtered = deduper.removeDuplicatePrefix(from: chunk)
            replayDeduper = deduper.isFinished ? nil : deduper
            return filtered
        }
    }
    private static let scrollbackCap = 64 * 1024
    private let locked = OSAllocatedUnfairLock<LockedState>(initialState: LockedState())
    private var pumpTask: Task<Void, Never>?
    private var statePumpTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?

    public init(id: UUID, agent: WorkspaceAgent, transport: any PTYTransport) {
        self.id = id
        self.agent = agent
        self.transport = transport
        startPump()
        startStatePump()
        observeForeground()
    }

    deinit {
        pumpTask?.cancel()
        statePumpTask?.cancel()
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
                _ = self?.locked.withLock { $0.subscribers.removeValue(forKey: key) }
            }
        }
    }

    public func clearScrollback() {
        locked.withLock { $0.scrollback = Data() }
    }

    public var state: AsyncStream<ConnectionState> {
        let key = UUID()
        return AsyncStream { continuation in
            let latest: ConnectionState = locked.withLock { state in
                state.stateSubscribers[key] = continuation
                return state.latestConnectionState
            }
            continuation.yield(latest)
            continuation.onTermination = { [weak self] _ in
                _ = self?.locked.withLock { $0.stateSubscribers.removeValue(forKey: key) }
            }
        }
    }

    public func connect() async throws { try await transport.connect() }
    public func send(_ bytes: Data) async throws { try await transport.send(bytes) }
    public func resize(_ size: TerminalSize) async throws { try await transport.resize(size) }
    public func close(_ reason: CloseReason = .userInitiated) async {
        await transport.close(reason)
        pumpTask?.cancel()
        statePumpTask?.cancel()
        finishAllSubscribers()
        finishAllStateSubscribers()
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

    private func startStatePump() {
        let upstream = transport.state
        statePumpTask = Task { [weak self] in
            for await state in upstream {
                if Task.isCancelled { return }
                self?.broadcast(state)
            }
            self?.finishAllStateSubscribers()
        }
    }

    private func broadcast(_ chunk: Data) {
        let (chunk, conts): (Data, [AsyncStream<Data>.Continuation]) = locked.withLock { state in
            let chunk = state.removeReconnectReplayDuplicate(from: chunk)
            guard !chunk.isEmpty else { return (Data(), []) }
            // Append to scrollback ring buffer, dropping oldest bytes once we
            // exceed the cap.
            state.scrollback.append(chunk)
            if state.scrollback.count > Self.scrollbackCap {
                state.scrollback.removeFirst(state.scrollback.count - Self.scrollbackCap)
            }
            return (chunk, Array(state.subscribers.values))
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

    private func broadcast(_ connectionState: ConnectionState) {
        let conts: [AsyncStream<ConnectionState>.Continuation] = locked.withLock { state in
            state.latestConnectionState = connectionState
            if connectionState.startsReconnectAttempt {
                state.replayDeduper = ReplayDeduper(snapshot: state.scrollback)
            }
            return Array(state.stateSubscribers.values)
        }
        for cont in conts { cont.yield(connectionState) }
    }

    private func finishAllStateSubscribers() {
        let conts: [AsyncStream<ConnectionState>.Continuation] = locked.withLock { state in
            let conts = Array(state.stateSubscribers.values)
            state.stateSubscribers.removeAll()
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

private extension ConnectionState {
    var startsReconnectAttempt: Bool {
        switch self {
        case let .connecting(attempt):
            return attempt > 1
        case .reconnecting:
            return true
        case .idle, .connected, .closed:
            return false
        }
    }
}

private struct ReplayDeduper {
    private let snapshot: Data
    private var offset: Int = 0
    private(set) var isFinished: Bool = false

    init(snapshot: Data) {
        self.snapshot = snapshot
        self.isFinished = snapshot.isEmpty
    }

    mutating func removeDuplicatePrefix(from chunk: Data) -> Data {
        guard !isFinished, !chunk.isEmpty else { return chunk }

        let matched = commonPrefixCount(chunk, snapshot, snapshotOffset: offset)
        guard matched > 0 else {
            isFinished = true
            return chunk
        }

        offset += matched
        if offset >= snapshot.count || matched < min(chunk.count, snapshot.count - (offset - matched)) {
            isFinished = true
        }

        guard matched < chunk.count else { return Data() }
        return Data(chunk.dropFirst(matched))
    }

    private func commonPrefixCount(_ chunk: Data, _ snapshot: Data, snapshotOffset: Int) -> Int {
        let maxCount = min(chunk.count, snapshot.count - snapshotOffset)
        guard maxCount > 0 else { return 0 }

        var matched = 0
        while matched < maxCount {
            let chunkByte = chunk[chunk.startIndex + matched]
            let snapshotByte = snapshot[snapshot.startIndex + snapshotOffset + matched]
            guard chunkByte == snapshotByte else { break }
            matched += 1
        }
        return matched
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
