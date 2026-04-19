import CoderAPI
import Foundation

/// Test double for `PTYTransport`. Drives the streams from test code via
/// `simulateInbound(_:)` / `simulateState(_:)` and records every `send` /
/// `resize` for later assertion.
///
/// Sendable via an internal lock — safe to inject into TCA reducers under
/// strict concurrency.
public final class MockPTYTransport: PTYTransport, @unchecked Sendable {
    public let inbound: AsyncThrowingStream<Data, Error>
    public let state: AsyncStream<ConnectionState>

    private let inboundContinuation: AsyncThrowingStream<Data, Error>.Continuation
    private let stateContinuation: AsyncStream<ConnectionState>.Continuation

    private let lock = NSLock()
    private var _sent: [Data] = []
    private var _resizes: [TerminalSize] = []
    private var _connectCalls: Int = 0
    private var _closeCalls: [CloseReason] = []

    public init() {
        var inboundCont: AsyncThrowingStream<Data, Error>.Continuation!
        self.inbound = AsyncThrowingStream { continuation in
            inboundCont = continuation
        }
        self.inboundContinuation = inboundCont

        var stateCont: AsyncStream<ConnectionState>.Continuation!
        self.state = AsyncStream { continuation in
            stateCont = continuation
        }
        self.stateContinuation = stateCont
        stateContinuation.yield(.idle)
    }

    public var sent: [Data]              { lock.withLock { _sent } }
    public var resizes: [TerminalSize]   { lock.withLock { _resizes } }
    public var connectCalls: Int         { lock.withLock { _connectCalls } }
    public var closeCalls: [CloseReason] { lock.withLock { _closeCalls } }

    public func connect() async throws {
        lock.withLock { _connectCalls += 1 }
        stateContinuation.yield(.connecting(attempt: 1))
        stateContinuation.yield(.connected)
    }

    public func send(_ bytes: Data) async throws {
        lock.withLock { _sent.append(bytes) }
    }

    public func resize(_ size: TerminalSize) async throws {
        lock.withLock { _resizes.append(size) }
    }

    public func checkAndReconnectIfNeeded() async {}

    public func close(_ reason: CloseReason) async {
        lock.withLock { _closeCalls.append(reason) }
        stateContinuation.yield(.closed(reason))
        stateContinuation.finish()
        inboundContinuation.finish()
    }

    // MARK: Test driving API

    /// Push bytes to subscribers as if the server sent them.
    public func simulateInbound(_ bytes: Data) {
        inboundContinuation.yield(bytes)
    }

    /// Push a state change to subscribers (e.g. `.reconnecting(attempt: 2, lastError: ...)`).
    public func simulateState(_ state: ConnectionState) {
        stateContinuation.yield(state)
    }

    /// Finish the inbound stream with an error (simulates fatal close).
    public func simulateClose(error: Error) {
        inboundContinuation.finish(throwing: error)
        stateContinuation.finish()
    }
}

/// Factory that hands out a fresh `MockPTYTransport` per call. The factory
/// itself records every produced instance so tests can inspect them.
public final class MockPTYTransportFactory: PTYTransportFactory, @unchecked Sendable {
    private let lock = NSLock()
    private var _produced: [MockPTYTransport] = []

    public init() {}

    public var produced: [MockPTYTransport] { lock.withLock { _produced } }

    public func make(
        deployment: Deployment,
        tls: TLSConfig,
        config: PTYTransportConfig,
        tokenProvider: @escaping @Sendable () async -> SessionToken?
    ) -> any PTYTransport {
        let mock = MockPTYTransport()
        lock.withLock { _produced.append(mock) }
        return mock
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
