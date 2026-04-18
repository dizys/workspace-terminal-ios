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
    public let inbound: AsyncThrowingStream<Data, Error>
    public let state: AsyncStream<ConnectionState>

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
    private var phase: Phase = .idle
    private var isClosed: Bool = false

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
        case .connected, .connecting:
            return // idempotent
        case .closing:
            throw PTYError.cancelled
        case .idle:
            break
        }
        try await openConnection(attempt: 1)
    }

    public func send(_ bytes: Data) async throws {
        guard let task else { throw PTYError.cancelled }
        let frame = ClientFrame.input(bytes)
        let payload: Data
        do {
            payload = try frame.jsonData()
        } catch {
            throw PTYError.encodingFailed("\(error)")
        }
        try await task.send(.data(payload))
    }

    public func resize(_ size: TerminalSize) async throws {
        guard let task else { throw PTYError.cancelled }
        let frame = ClientFrame.resize(size)
        let payload: Data
        do {
            payload = try frame.jsonData()
        } catch {
            throw PTYError.encodingFailed("\(error)")
        }
        try await task.send(.data(payload))
    }

    public func close(_ reason: CloseReason) async {
        guard !isClosed else { return }
        isClosed = true
        phase = .closing
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
        let reason = code == 0
            ? CloseReason.fatal(code: 0, reason: error.localizedDescription)
            : CloseClassifier.classify(code: code, reason: reasonString)
        finishWithReason(reason)
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
