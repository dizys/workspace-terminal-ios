# PTYTransport — Design

**Status:** Approved (informed by ground-truth investigation of `coder/coder` Go source, see `.refs/coder/`).
**Date:** 2026-04-18
**Owner:** M2 Terminal MVP — bottom-up, transport layer first.

## Goal

A reconnecting WebSocket transport for Coder's `/api/v2/workspaceagents/{id}/pty` endpoint that is bug-compatible with both the Go CLI (`cli/exp_rpty.go`) and web UI (`site/src/modules/terminal/WorkspaceTerminal.tsx`), with first-class support for devcontainer sub-agents, mobile-grade reconnection, and full unit coverage via an in-process WebSocket echo server. The transport is consumed by `TerminalFeature` (TCA) and never reaches into UI.

## Ground truth (Coder source citations)

All decisions below are verified against the local `coder/coder` checkout at `/Users/ziyangzeng/Projects/ideas/coder-terminal/.refs/coder/`.

### Wire protocol
- Endpoint: `GET /api/v2/workspaceagents/{id}/pty` upgraded to WebSocket. Source: `coderd/workspaceapps/proxy.go:165`.
- **All frames are binary in both directions.** Server uses `websocket.MessageBinary` for the wrapped `net.Conn`. There is no text-frame channel. Source: `coderd/workspaceapps/proxy.go:770`.
- **Server → client**: raw PTY bytes, no envelope.
- **Client → server**: each frame is a complete JSON object matching `ReconnectingPTYRequest { data?: string, height?: uint16, width?: uint16 }`. Server decodes via `json.NewDecoder` so one frame = one JSON value. Resize and data may be combined in the same frame. Source: `codersdk/workspacesdk/agentconn.go:196-200` + `agent/reconnectingpty/reconnectingpty.go:207-234`.
- Query params (in CLI order): `reconnect=<uuid>` (**required**), `width=<uint>`, `height=<uint>` (default 80×80 server-side), `command=<string>` (always set, may be empty), then optional `container`, `container_user`, `backend_type` (`buffered` | `screen`). Source: `coderd/workspaceapps/proxy.go:736-743` + `cli/exp_rpty.go:154-188`.
- Auth: `Coder-Session-Token` header on the WS handshake. Server precedence: cookie → query → header → bearer → access_token. Source: `coderd/httpmw/apikey.go:925-956`.
- No subprotocol negotiation (`Sec-WebSocket-Protocol` is not set). Source: `coderd/workspaceapps/proxy.go:752-760`.

### Reconnect semantics
- Server holds the PTY for **5 minutes** of idle (`reconnectingpty.go:62-64`).
- Ring buffer is **64 KiB** (`buffered.go:52`). On reconnect with the same UUID, the server does a single `conn.Write(prevBuf)` of the entire buffer — no delimiter, no "live now" marker (`buffered.go:223-230`).
- Server pings every **15s** with 15s timeout (`coderd/httpapi/websocket.go:16,53`). Client must respond to control frames (URLSession does this automatically) but does **not** send application-level pings.
- Web UI reconnect: exponential backoff 1s base, 6 attempts, same UUID. CLI does not reconnect.
- Close codes:
  - `1000` (normal) — graceful close, web UI sends this on unmount.
  - `1001` (going away) — server "Ping failed".
  - `1011` (internal error) — `"dial workspace agent: ..."` or `"dial: ..."`. Means agent unreachable (workspace stopped, agent crashed, etc.).

## Public API (PTYTransport package)

```swift
public protocol PTYTransport: Sendable {
    var inbound: AsyncThrowingStream<Data, Error> { get }
    var state: AsyncStream<ConnectionState> { get }

    func connect() async throws
    func send(_ bytes: Data) async throws
    func resize(_ size: TerminalSize) async throws
    func close(_ reason: CloseReason) async
}

public struct PTYTransportConfig: Sendable {
    let agentID: UUID
    let reconnectToken: UUID
    let initialSize: TerminalSize
    let command: String                  // "" allowed
    let container: String?
    let containerUser: String?
    let backendType: BackendType?        // server default if nil
    let reconnectPolicy: ReconnectPolicy
}

public enum BackendType: String, Sendable, Codable { case buffered, screen }

public enum ConnectionState: Sendable, Equatable {
    case idle
    case connecting(attempt: Int)
    case connected
    case reconnecting(attempt: Int, lastError: PTYError?)
    case closed(CloseReason)
}

public enum CloseReason: Sendable, Equatable {
    case userInitiated                              // we sent 1000
    case agentUnreachable(detail: String)           // 1011 with "dial..."
    case authExpired                                // HTTP 401 on upgrade
    case serverTimeout                              // 1001 ping failed (transient)
    case fatal(code: Int, reason: String)
}

public enum PTYError: Error, Sendable, Equatable {
    case handshakeFailed(status: Int?, detail: String)
    case closed(CloseReason)
    case encodingFailed(String)
    case cancelled
}

public struct ReconnectPolicy: Sendable {
    let baseDelay: TimeInterval                     // 1.0
    let maxDelay: TimeInterval                      // 30.0
    let maxAttempts: Int?                           // nil = unlimited
    let jitter: ClosedRange<Double>                 // 0.85...1.15
    public static let `default` = ReconnectPolicy(...)
}

public protocol PTYTransportFactory: Sendable {
    func make(deployment: Deployment, tls: TLSConfig, config: PTYTransportConfig,
              tokenProvider: @escaping @Sendable () async -> SessionToken?) -> any PTYTransport
}
```

## Module layout

```
Packages/PTYTransport/Sources/PTYTransport/
  PTYTransport.swift                  // protocol, public re-exports
  Models/
    ConnectionState.swift
    CloseReason.swift
    PTYError.swift
    ReconnectPolicy.swift
    PTYTransportConfig.swift
    BackendType.swift
  Wire/
    ClientFrame.swift                 // pure encoder for {data,h,w}
    URLBuilder.swift                  // pure URL construction
    CloseClassifier.swift             // WS close code → CloseDisposition
  Live/
    LivePTYTransport.swift            // URLSessionWebSocketTask impl
    Reconnector.swift                 // backoff + jitter loop
  Mock/
    MockPTYTransport.swift            // for downstream reducer tests
  PTYTransportFactory.swift           // live + dependency wiring

Packages/PTYTransport/Tests/PTYTransportTests/
  Wire/
    ClientFrameTests.swift
    URLBuilderTests.swift
    CloseClassifierTests.swift
  Models/
    ReconnectPolicyTests.swift
  Live/
    LivePTYTransportTests.swift       // hits NWListener echo server
  Support/
    EchoPTYServer.swift               // NWListener-based fixture
    GoldenFrames.swift                // canned frame sequences from coder/coder tests
```

## Concurrency model

- `LivePTYTransport` is an `actor`. Each instance owns one URLSessionWebSocketTask, one inbound `AsyncThrowingStream.Continuation`, one state stream continuation, and a serial outbound writer task.
- Public `send`/`resize` enqueue to an internal `AsyncChannel<Data>` (unbounded — keystrokes are tiny). The writer task drains and `webSocketTask.send(.data(...))`. Failures bubble back through the state stream as `.reconnecting(...)`.
- Inbound: `Task` calls `webSocketTask.receive()` in a loop, yielding `Data` to the inbound stream. On error or non-data message, classify and either trigger reconnect or finish the stream.
- `connect()` is idempotent — re-entry while already connected is a no-op; while reconnecting, it short-circuits the backoff. The reducer can use this to "give up waiting and try now."
- `close(_)` cancels the reconnect loop, sends WS close `1000`, finishes both streams.

## Test strategy

Per `docs/testing.md` we target ≥85% line coverage for PTYTransport. Pyramid:

- **Unit (pure):** `ClientFrameTests`, `URLBuilderTests`, `CloseClassifierTests`, `ReconnectPolicyTests`. Run on every save. ~60% of total.
- **Component:** `LivePTYTransportTests` against `EchoPTYServer` — an in-process `NWListener` WebSocket server that replays the exact frame sequences captured from `coder/coder`'s own test suite (`coderd/workspaceapps/apptest/apptest.go:2367-2426`). Covers happy path, server-pings (no client-pings expected), reconnect with replay, close-code classification.
- **Integration (later, M4):** XCTest hits a real Coder Docker container in CI.

## Non-goals (explicit)

- **No client-side ping/heartbeat.** The server pings; we just stay alive enough to answer.
- **No keystroke buffering during reconnect.** UI shows "reconnecting…" and disables input. Matches web UI; safer than replaying user keys against an unknown prompt state.
- **No SSH fallback.** Per ADR-0003.
- **No protocol version negotiation.** Coder doesn't have one for the PTY endpoint. We pin behavior to the `cli/exp_rpty.go` shape and follow API surface changes via integration tests.

## Verified non-issues

- `WorkspaceAgent.parent_id` decoder: `google/uuid v1.6.0` `NullUUID.MarshalJSON` emits literal `null` when `!Valid`, so our existing `parentID: UUID?` decode is fine. Confirmed via `coder/go.mod:165`.
