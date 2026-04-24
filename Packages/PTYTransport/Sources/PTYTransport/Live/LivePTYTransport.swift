import CoderAPI
import Foundation

/// Live `PTYTransport` backed by `URLSessionWebSocketTask`.
///
/// Actor-isolated: every public mutation funnels through the actor's executor
/// so two concurrent `send`s can never race the underlying task. Inbound
/// bytes flow on a separate `Task` that drains `webSocketTask.receive()` and
/// yields into the public `inbound` stream.
///
/// Bug-compatible (verified against `.refs/coder/`):
/// - Auth via `Coder-Session-Token` header on the WS handshake
///   (`codersdk/workspacesdk/workspacesdk.go:374-378`).
/// - All frames binary; client→server payload is JSON
///   (`codersdk/workspacesdk/agentconn.go:196-200`).
/// - No client-side ping; URLSession answers server pings automatically
///   (`coderd/httpapi/websocket.go:16-22`, server pings every 15s).
public actor LivePTYTransport: PTYTransport {
    public nonisolated let inbound: AsyncThrowingStream<Data, Error>
    public nonisolated let state: AsyncStream<ConnectionState>

    private let inboundContinuation: AsyncThrowingStream<Data, Error>.Continuation
    private let stateContinuation: AsyncStream<ConnectionState>.Continuation

    private let deployment: Deployment
    private let tls: TLSConfig
    private let config: PTYTransportConfig
    private let tokenProvider: @Sendable () async -> SessionToken?
    private let userAgent: String

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var phase: Phase = .idle
    private var isClosed: Bool = false
    private var currentAttempt: Int = 0

    private enum Phase {
        case idle
        case connecting(attempt: Int)
        case connected
        case closing
    }

    public init(
        deployment: Deployment,
        tls: TLSConfig = .default,
        config: PTYTransportConfig,
        tokenProvider: @escaping @Sendable () async -> SessionToken?,
        userAgent: String = "WorkspaceTerminal-iOS"
    ) {
        self.deployment = deployment
        self.tls = tls
        self.config = config
        self.tokenProvider = tokenProvider
        self.userAgent = userAgent

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

    public func connect() async throws {
        switch phase {
        case .connected:
            return // idempotent
        case .connecting:
            guard reconnectTask != nil else { return }
            reconnectTask?.cancel()
            reconnectTask = nil
            try await openConnection(attempt: max(currentAttempt, 1))
            return
        case .closing:
            throw PTYError.cancelled
        case .idle:
            break
        }
        try await openConnection(attempt: 1)
    }

    public func send(_ bytes: Data) async throws {
        try await sendFrame(.input(bytes))
    }

    public func resize(_ size: TerminalSize) async throws {
        try await sendFrame(.resize(size))
    }

    private func sendFrame(_ frame: ClientFrame) async throws {
        guard let task else { throw PTYError.cancelled }
        let payload: Data
        do {
            payload = try frame.jsonData()
        } catch {
            throw PTYError.encodingFailed("\(error)")
        }
        do {
            try await task.send(.data(payload))
        } catch {
            handleWriteError(error, on: task)
            throw PTYError.closed(.serverTimeout)
        }
    }

    public func checkAndReconnectIfNeeded() async {
        guard !isClosed else { return }
        guard let task else {
            if reconnectTask != nil {
                reconnectTask?.cancel()
                reconnectTask = nil
                try? await openConnection(attempt: max(currentAttempt, 1))
            }
            return
        }

        // URLSessionWebSocketTask.state goes to .completed or .canceling
        // when the underlying TCP connection died while the app was suspended.
        // Do NOT send a probe frame — if the connection is half-dead, the
        // probe bytes can be echoed by the remote shell as literal text
        // (especially inside tmux with send-keys -M). Just check the state.
        let state = task.state
        if state == .completed || state == .canceling || state == .suspended {
            scheduleReconnect(after: .serverTimeout)
        }
        // If state is .running, the connection may still be alive. The receive
        // loop will detect any actual close and trigger reconnect on its own.
    }

    public func close(_ reason: CloseReason) async {
        guard !isClosed else { return }
        isClosed = true
        phase = .closing
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveLoop?.cancel()
        receiveLoop = nil
        // Send WS close 1000 (matches web UI on unmount).
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        stateContinuation.yield(.closed(reason))
        stateContinuation.finish()
        inboundContinuation.finish()
    }

    // MARK: - Internals

    private func openConnection(attempt: Int) async throws {
        phase = .connecting(attempt: attempt)
        currentAttempt = attempt
        stateContinuation.yield(.connecting(attempt: attempt))

        let url = PTYURLBuilder.makeURL(deployment: deployment, config: config)
        let request = await buildRequest(url: url)

        let urlSession = URLSession(configuration: .ephemeral)
        session = urlSession

        let webSocketTask = urlSession.webSocketTask(with: request)
        task = webSocketTask
        webSocketTask.resume()

        phase = .connected
        stateContinuation.yield(.connected)
        startReceiveLoop(on: webSocketTask)
    }

    private func buildRequest(url: URL) async -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token = await tokenProvider() {
            request.setValue(token.value, forHTTPHeaderField: SessionToken.httpHeaderName)
        }
        return request
    }

    private func startReceiveLoop(on task: URLSessionWebSocketTask) {
        receiveLoop = Task { [weak self] in
            await self?.runReceiveLoop(on: task)
        }
    }

    private func runReceiveLoop(on task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .data(let bytes):
                    inboundContinuation.yield(bytes)
                case .string(let s):
                    // Coder server uses binary only; if a text frame leaks
                    // through (proxy stripping, etc.), pass it as UTF-8.
                    inboundContinuation.yield(Data(s.utf8))
                @unknown default:
                    break
                }
            } catch {
                handleReceiveError(error, on: task)
                return
            }
        }
    }

    private func handleReceiveError(_ error: Error, on task: URLSessionWebSocketTask) {
        // Pull the close code if available; URLSession surfaces it on the task.
        let code = task.closeCode.rawValue
        let reasonString: String = {
            if let data = task.closeReason, let s = String(data: data, encoding: .utf8) { return s }
            return ""
        }()
        let reason: CloseReason
        if code == 0 {
            // No close frame — pure network failure. Most often this is iOS
            // suspending the WS task in the background, then URLSession
            // surfacing it as `cancelled` or `networkConnectionLost` when we
            // try to receive. Treat these as transient and reconnectable; the
            // Coder server still holds the reconnecting-PTY ring buffer.
            if isTransientNetworkError(error) {
                reason = .serverTimeout
            } else {
                reason = .fatal(code: 0, reason: error.localizedDescription)
            }
        } else {
            reason = CloseClassifier.classify(code: code, reason: reasonString)
        }

        if shouldReconnect(after: reason) {
            scheduleReconnect(after: reason)
        } else {
            finishWithReason(reason)
        }
    }

    private func isTransientNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        switch nsError.code {
        case NSURLErrorCancelled,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorTimedOut,
             NSURLErrorBackgroundSessionWasDisconnected:
            return true
        default:
            return false
        }
    }

    private func handleWriteError(_ error: Error, on task: URLSessionWebSocketTask) {
        guard self.task === task, !isClosed else { return }
        if shouldReconnect(after: .serverTimeout) {
            scheduleReconnect(after: .serverTimeout)
        } else {
            finishWithReason(.fatal(code: 0, reason: error.localizedDescription))
        }
    }

    /// Decide if a close warrants automatic reconnect with the same UUID
    /// (server still holds the ring buffer for ~5min).
    private func shouldReconnect(after reason: CloseReason) -> Bool {
        switch reason {
        case .serverTimeout:
            return true
        case .userInitiated, .authExpired, .agentUnreachable, .fatal:
            return false
        }
    }

    /// Surface `.reconnecting(attempt:)` immediately; sleep per policy; dial.
    /// Any further failure flows back through `handleReceiveError` → recursion
    /// stops naturally when policy.maxAttempts is exhausted.
    private func scheduleReconnect(after reason: CloseReason) {
        reconnectTask?.cancel()
        reconnectTask = nil

        let nextAttempt = currentAttempt + 1
        let policy = config.reconnectPolicy
        if let max = policy.maxAttempts, nextAttempt > max {
            finishWithReason(.fatal(code: -1, reason: "reconnect attempts exhausted (\(max))"))
            return
        }

        // Tear down the dead task before scheduling the new dial.
        task?.cancel(with: .abnormalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        receiveLoop?.cancel()
        receiveLoop = nil

        phase = .connecting(attempt: nextAttempt)
        currentAttempt = nextAttempt
        stateContinuation.yield(.reconnecting(attempt: nextAttempt, lastError: PTYError.closed(reason)))

        let delay = policy.delay(forAttempt: nextAttempt)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            try? await self?.openConnection(attempt: nextAttempt)
        }
    }

    private func finishWithReason(_ reason: CloseReason) {
        guard !isClosed else { return }
        isClosed = true
        phase = .closing
        stateContinuation.yield(.closed(reason))
        stateContinuation.finish()
        inboundContinuation.finish(throwing: PTYError.closed(reason))
        receiveLoop = nil
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }
}
