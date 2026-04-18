import Foundation
import Network

/// In-process WebSocket server that mimics Coder's PTY endpoint just enough
/// to drive `LivePTYTransport` through realistic flows.
///
/// Built on `NWListener` + `NWProtocolWebSocket` (Apple-first; no
/// third-party deps). Always listens on localhost; chooses a random free
/// port unless one is supplied.
///
/// Usage:
/// ```swift
/// let server = try await EchoPTYServer.start()
/// server.script([
///     .send(Data("$ ".utf8)),
///     .expectClientFrame { $0.contains("\"data\":\"echo test\\r\"") },
///     .send(Data("echo test\r\ntest\r\n$ ".utf8)),
///     .close(code: 1000, reason: ""),
/// ])
/// // ... drive client against server.url ...
/// server.stop()
/// ```
final class EchoPTYServer: @unchecked Sendable {
    /// One scripted action.
    enum Step: Sendable {
        /// Server → client: send raw bytes inside a binary WS frame.
        case send(Data)
        /// Server → client: small delay before the next step.
        case sleep(TimeInterval)
        /// Server → client: close the connection with a code + reason.
        case close(code: UInt16, reason: String)
        /// Wait for the next client → server frame and assert via predicate.
        /// The closure receives the JSON string the client sent (binary frame
        /// payload decoded as UTF-8).
        case expectClientFrame(@Sendable (String) -> Bool)
    }

    /// Things observed during a session — assert on these from the test body.
    struct Recording: Sendable {
        var receivedFrames: [Data] = []
        var clientConnected: Bool = false
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "EchoPTYServer", qos: .userInitiated)
    private var connection: NWConnection?
    private var script: [Step] = []
    private var scriptIndex: Int = 0
    private var recording = Recording()
    private let lock = NSLock()
    private var clientReadyContinuation: CheckedContinuation<Void, Never>?
    private var firstFrameContinuations: [CheckedContinuation<Data, Error>] = []

    /// HTTP path the server advertises. The test client should hit this URL.
    let path: String

    init(path: String = "/api/v2/workspaceagents/00000000-0000-0000-0000-000000000000/pty") throws {
        let parameters = NWParameters(tls: nil)
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        self.listener = try NWListener(using: parameters, on: .any)
        self.path = path
    }

    /// Begin listening. Returns the bound `URL`.
    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let port = self.listener.port?.rawValue ?? 0
                    var components = URLComponents()
                    components.scheme = "ws"
                    components.host = "127.0.0.1"
                    components.port = Int(port)
                    components.path = self.path
                    continuation.resume(returning: components.url!)
                case .failed(let err):
                    continuation.resume(throwing: err)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
        }
    }

    func script(_ steps: [Step]) {
        lock.withLock {
            self.script = steps
            self.scriptIndex = 0
        }
    }

    func recordingSnapshot() -> Recording {
        lock.withLock { recording }
    }

    /// Awaits the first client connection (handshake complete).
    func waitForClient() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if recording.clientConnected {
                lock.unlock()
                continuation.resume()
                return
            }
            clientReadyContinuation = continuation
            lock.unlock()
        }
    }

    /// Suspends until the next client → server frame arrives, returning its raw bytes.
    func awaitNextClientFrame() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                firstFrameContinuations.append(continuation)
            }
        }
    }

    func stop() {
        connection?.cancel()
        listener.cancel()
    }

    // MARK: - Internals

    private func accept(_ connection: NWConnection) {
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.lock.withLock {
                    self.recording.clientConnected = true
                    if let cont = self.clientReadyContinuation {
                        self.clientReadyContinuation = nil
                        cont.resume()
                    }
                }
                self.startReceive(on: connection)
                self.advanceScript()
            case .failed(let err):
                self.failPendingFrameWaiters(with: err)
            case .cancelled:
                self.failPendingFrameWaiters(with: NWError.posix(.ECANCELED))
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func startReceive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.lock.withLock {
                    self.recording.receivedFrames.append(data)
                    if !self.firstFrameContinuations.isEmpty {
                        let cont = self.firstFrameContinuations.removeFirst()
                        cont.resume(returning: data)
                    }
                }
                self.tryExpectClientFrame(payload: data)
            }
            // Keep receiving until close / error.
            if error == nil, context?.isFinal != true {
                self.startReceive(on: connection)
            }
        }
    }

    private func tryExpectClientFrame(payload: Data) {
        // If the next scripted step is .expectClientFrame, run it now and advance.
        lock.lock()
        guard scriptIndex < script.count, case let .expectClientFrame(predicate) = script[scriptIndex] else {
            lock.unlock()
            return
        }
        scriptIndex += 1
        lock.unlock()
        let asString = String(decoding: payload, as: UTF8.self)
        _ = predicate(asString)
        advanceScript()
    }

    private func advanceScript() {
        guard let connection else { return }

        lock.lock()
        guard scriptIndex < script.count else {
            lock.unlock()
            return
        }
        let step = script[scriptIndex]
        // Only auto-advance for non-expect steps; expect steps wait for input.
        if case .expectClientFrame = step {
            lock.unlock()
            return
        }
        scriptIndex += 1
        lock.unlock()

        switch step {
        case .send(let data):
            let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
            let context = NWConnection.ContentContext(identifier: "send", metadata: [metadata])
            connection.send(content: data, contentContext: context, isComplete: true,
                            completion: .contentProcessed { [weak self] _ in
                self?.advanceScript()
            })
        case .sleep(let interval):
            queue.asyncAfter(deadline: .now() + interval) { [weak self] in
                self?.advanceScript()
            }
        case .close(let code, let reason):
            let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
            metadata.closeCode = .protocolCode(.init(rawValue: code) ?? .normalClosure)
            let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
            let payload = Data(reason.utf8)
            connection.send(content: payload.isEmpty ? nil : payload, contentContext: context, isComplete: true,
                            completion: .contentProcessed { [weak self] _ in
                self?.connection?.cancel()
            })
        case .expectClientFrame:
            break // handled in tryExpectClientFrame
        }
    }

    private func failPendingFrameWaiters(with error: Error) {
        lock.withLock {
            for cont in firstFrameContinuations {
                cont.resume(throwing: error)
            }
            firstFrameContinuations.removeAll()
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
