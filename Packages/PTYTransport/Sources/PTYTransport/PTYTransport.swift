import CoderAPI
import Foundation

/// Terminal dimensions in rows × cols.
///
/// Server defaults to 80×80 if zero is sent (`coderd/workspaceapps/proxy.go:739-740`),
/// so callers should always supply real dimensions or fall back to the
/// industry-standard 80×24.
public struct TerminalSize: Sendable, Equatable, Codable {
    public let rows: Int
    public let cols: Int

    public init(rows: Int, cols: Int) {
        precondition(rows > 0 && cols > 0, "Terminal size must be positive")
        self.rows = rows
        self.cols = cols
    }
}

/// Reconnecting WebSocket transport for Coder's PTY endpoint.
///
/// One transport instance per logical terminal session. The caller (typically
/// `TerminalFeature`) holds the `reconnectToken` for the life of the tab so
/// that reconnects after a network blip resume the server's ring buffer.
///
/// See `docs/plans/2026-04-18-pty-transport-design.md` for the full contract
/// and `.refs/coder/` for the upstream protocol source-of-truth.
public protocol PTYTransport: Sendable {
    /// Raw PTY bytes from the server. Consumers (e.g. SwiftTerm) feed these
    /// directly into the emulator. Stream finishes (throws) on terminal close;
    /// transient reconnects are surfaced via `state` and do **not** interrupt
    /// this stream.
    var inbound: AsyncThrowingStream<Data, Error> { get }

    /// Lifecycle changes. New subscribers see the latest value immediately.
    var state: AsyncStream<ConnectionState> { get }

    /// Open the connection (and start the reconnect loop). Idempotent —
    /// re-entry while already connected is a no-op.
    func connect() async throws

    /// Send user input. Wrapped on the wire as a binary WS frame containing
    /// `{"data":"..."}` JSON.
    func send(_ bytes: Data) async throws

    /// Send a window-size change. Wrapped as `{"height":r,"width":c}`.
    func resize(_ size: TerminalSize) async throws

    /// Graceful close — sends WS code 1000 and finishes both streams.
    func close(_ reason: CloseReason) async

    /// Proactively check if the connection is still alive; if not, tear down
    /// the stale socket and reconnect with the same UUID. Call this on app
    /// foreground — iOS suspends WebSocket tasks in the background, so the
    /// server may have closed them (15s ping timeout) without our receive
    /// loop noticing. Implementations should also collapse any pending
    /// reconnect backoff so foreground recovery starts immediately.
    func checkAndReconnectIfNeeded() async
}

/// Factory for live transports — one per terminal tab. Injected via TCA's
/// `@Dependency` so tests can substitute a `MockPTYTransport`.
public protocol PTYTransportFactory: Sendable {
    func make(
        deployment: Deployment,
        tls: TLSConfig,
        config: PTYTransportConfig,
        tokenProvider: @escaping @Sendable () async -> SessionToken?
    ) -> any PTYTransport
}
