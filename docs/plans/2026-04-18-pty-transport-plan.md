# Plan: PTYTransport Package (M2 — Bottom-Up)

**Goal**: Ship a fully-tested `PTYTransport` Swift package: protocol, mock, and live `URLSessionWebSocketTask` implementation with reconnect, against an in-process WS echo server harness, ≥85% line coverage. Bug-compatible with `coder/coder` Go server (verified at `.refs/coder/`).

**Architecture**: See `docs/plans/2026-04-18-pty-transport-design.md`. Public API is one `PTYTransport` actor protocol + factory; wire encoder/decoder is pure value layer; reconnect is a separate `Reconnector` with backoff+jitter; tests run against `EchoPTYServer` built on `NWListener`.

**Tech Stack**: Swift 6 (strict concurrency), `URLSessionWebSocketTask`, `Network.framework` (`NWListener` for tests), XCTest, Swift Testing where it doesn't fight TCA fixtures, no third-party deps.

**Source-of-truth references** (always cite when implementing protocol-touching code):
- `.refs/coder/coderd/workspaceapps/proxy.go` (server PTY handler, lines 695-804)
- `.refs/coder/codersdk/workspacesdk/workspacesdk.go` (Go client SDK, lines 309-391)
- `.refs/coder/codersdk/workspacesdk/agentconn.go` (request struct, lines 196-200)
- `.refs/coder/cli/exp_rpty.go` (CLI client behavior)
- `.refs/coder/site/src/modules/terminal/WorkspaceTerminal.tsx` (web UI behavior, esp. reconnect)
- `.refs/coder/coderd/httpapi/websocket.go` (server pings)
- `.refs/coder/coderd/workspaceapps/apptest/apptest.go:2367-2426` (golden frame test)

## Build verification

Local build still blocked by the host `sandbox-exec: Operation not permitted` against the FB Xcode. **Each step's "verify" step uses `swift test --package-path Packages/PTYTransport`** when available; if the sandbox issue persists, the user runs them manually after each commit batch and we proceed assuming green. We do NOT skip writing tests just because we can't run them.

## Task Dependencies

| Group | Steps | Files Touched | Parallelizable |
|-------|-------|---------------|----------------|
| 1 (pure value layer) | 1, 2, 3, 4 | `Models/*.swift`, `Wire/ClientFrame.swift`, `Wire/URLBuilder.swift` | Yes (no shared files) |
| 2 (state model) | 5, 6 | `Models/ConnectionState.swift`, `Wire/CloseClassifier.swift` | Yes |
| 3 (public protocol) | 7, 8 | `PTYTransport.swift`, `Mock/MockPTYTransport.swift` | No (8 depends on 7) |
| 4 (test harness) | 9 | `Tests/Support/EchoPTYServer.swift` | No |
| 5 (live impl) | 10, 11, 12, 13 | `Live/LivePTYTransport.swift`, `Live/Reconnector.swift` | No (sequential within actor) |
| 6 (factory + DI) | 14 | `PTYTransportFactory.swift` | No |
| 7 (e2e + cleanup) | 15, 16 | All | No |

---

## Step 0: Package scaffolding sanity check

**File**: `Packages/PTYTransport/Package.swift`

Already has `Foundation` + `CoderAPI` dep. Verify by Read; no edit unless missing `Network.framework` for the test harness — but `Network` is part of Foundation on Apple platforms so no manifest change needed.

### 0a. Verify
```bash
ls Packages/PTYTransport/Sources/PTYTransport/  # only PTYTransport.swift today
ls Packages/PTYTransport/Tests/PTYTransportTests/
```

### 0b. Delete the placeholder constant
`PTYTransport.swift` currently exposes `defaultHeartbeatInterval = 25`. Per ground truth we don't ping. Remove the constant, keep `TerminalSize` (used elsewhere). New file becomes a near-empty namespace doc that we'll repopulate.

### 0c. Commit
```bash
git add Packages/PTYTransport && git commit -m "chore(PTYTransport): clear placeholder; we don't ping (server pings)"
```

---

## Step 1: `BackendType` and `ReconnectPolicy` value types

**File**: `Packages/PTYTransport/Sources/PTYTransport/Models/BackendType.swift`, `Packages/PTYTransport/Sources/PTYTransport/Models/ReconnectPolicy.swift`

### 1a. Failing test
**File**: `Packages/PTYTransport/Tests/PTYTransportTests/Models/ReconnectPolicyTests.swift`
```swift
import XCTest
@testable import PTYTransport

final class ReconnectPolicyTests: XCTestCase {
    func test_default_matchesWebUISafeMobileDefaults() {
        let p = ReconnectPolicy.default
        XCTAssertEqual(p.baseDelay, 1.0)
        XCTAssertEqual(p.maxDelay, 30.0)
        XCTAssertNil(p.maxAttempts) // mobile reality: keep trying
    }

    func test_delayForAttempt_growsExponentiallyAndCaps() {
        let p = ReconnectPolicy(baseDelay: 1, maxDelay: 8, maxAttempts: nil, jitter: 1.0...1.0)
        XCTAssertEqual(p.delay(forAttempt: 1), 1)
        XCTAssertEqual(p.delay(forAttempt: 2), 2)
        XCTAssertEqual(p.delay(forAttempt: 3), 4)
        XCTAssertEqual(p.delay(forAttempt: 4), 8)
        XCTAssertEqual(p.delay(forAttempt: 5), 8) // capped
        XCTAssertEqual(p.delay(forAttempt: 99), 8)
    }

    func test_delayForAttempt_appliesJitterWithinRange() {
        let p = ReconnectPolicy(baseDelay: 10, maxDelay: 100, maxAttempts: nil, jitter: 0.5...1.5)
        for _ in 0..<200 {
            let d = p.delay(forAttempt: 2)  // base 20
            XCTAssertGreaterThanOrEqual(d, 10)
            XCTAssertLessThanOrEqual(d, 30)
        }
    }
}
```

### 1b. Run failing
```bash
swift test --package-path Packages/PTYTransport --filter ReconnectPolicyTests
```

### 1c. Implement
```swift
// Models/BackendType.swift
import Foundation

/// Coder server's reconnecting-PTY backend. Default (nil) lets the server pick.
/// Source: .refs/coder/agent/reconnectingpty/reconnectingpty.go:69-91
public enum BackendType: String, Sendable, Codable, CaseIterable {
    case buffered, screen
}
```
```swift
// Models/ReconnectPolicy.swift
import Foundation

public struct ReconnectPolicy: Sendable, Equatable {
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let maxAttempts: Int?
    public let jitter: ClosedRange<Double>

    public init(baseDelay: TimeInterval, maxDelay: TimeInterval,
                maxAttempts: Int?, jitter: ClosedRange<Double>) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.maxAttempts = maxAttempts
        self.jitter = jitter
    }

    /// Web UI uses (1s, 6 attempts) but mobile networks drop for minutes;
    /// we keep retrying with capped 30s delay.
    public static let `default` = ReconnectPolicy(
        baseDelay: 1.0, maxDelay: 30.0, maxAttempts: nil, jitter: 0.85...1.15
    )

    /// Delay in seconds before the Nth attempt (1-indexed).
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponent = max(0, attempt - 1)
        let raw = baseDelay * pow(2.0, Double(exponent))
        let capped = min(maxDelay, raw)
        return capped * Double.random(in: jitter)
    }
}
```

### 1d. Verify green
```bash
swift test --package-path Packages/PTYTransport --filter ReconnectPolicyTests
```

### 1e. Commit
```bash
git add Packages/PTYTransport && git commit -m "feat(PTYTransport): BackendType + ReconnectPolicy with TDD"
```

---

## Step 2: `ClientFrame` JSON encoder (pure)

**File**: `Packages/PTYTransport/Sources/PTYTransport/Wire/ClientFrame.swift`

### 2a. Failing test
**File**: `Packages/PTYTransport/Tests/PTYTransportTests/Wire/ClientFrameTests.swift`
```swift
import XCTest
@testable import PTYTransport

final class ClientFrameTests: XCTestCase {
    // ReconnectingPTYRequest{ data?, height?, width? }
    // Source: .refs/coder/codersdk/workspacesdk/agentconn.go:196-200
    func test_input_emitsDataOnly() throws {
        let frame = ClientFrame.input(Data("hi".utf8))
        XCTAssertEqual(try frame.jsonString(), #"{"data":"hi"}"#)
    }

    func test_resize_emitsHeightAndWidth_omitsData() throws {
        let frame = ClientFrame.resize(TerminalSize(rows: 40, cols: 120))
        // Sorted keys: height, width
        XCTAssertEqual(try frame.jsonString(), #"{"height":40,"width":120}"#)
    }

    func test_input_handlesUTF8MultibyteCorrectly() throws {
        let frame = ClientFrame.input(Data("héllo🌍".utf8))
        XCTAssertEqual(try frame.jsonString(), #"{"data":"héllo🌍"}"#)
    }

    func test_input_lossyOnInvalidUTF8() throws {
        // 0xFF is never valid UTF-8 — should not throw, should emit replacement.
        let frame = ClientFrame.input(Data([0x68, 0xFF, 0x69]))
        let s = try frame.jsonString()
        XCTAssertTrue(s.contains(#""data":"#))
        XCTAssertFalse(s.isEmpty)
    }
}
```

### 2b. Run failing
```bash
swift test --package-path Packages/PTYTransport --filter ClientFrameTests
```

### 2c. Implement
```swift
import Foundation

/// One frame on the wire from client to Coder server. Always sent inside a
/// WS binary message containing exactly one JSON object.
/// Mirrors Go's `ReconnectingPTYRequest`:
///   .refs/coder/codersdk/workspacesdk/agentconn.go:196-200
struct ClientFrame: Encodable, Equatable {
    var data: String?
    var height: UInt16?
    var width: UInt16?

    static func input(_ bytes: Data) -> ClientFrame {
        // String(decoding:as:) substitutes U+FFFD for invalid UTF-8 — safer
        // than throwing in the keystroke hot path.
        ClientFrame(data: String(decoding: bytes, as: UTF8.self), height: nil, width: nil)
    }

    static func resize(_ size: TerminalSize) -> ClientFrame {
        ClientFrame(data: nil, height: UInt16(size.rows), width: UInt16(size.cols))
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    func jsonData() throws -> Data {
        try Self.encoder.encode(self)
    }

    func jsonString() throws -> String {
        String(decoding: try jsonData(), as: UTF8.self)
    }
}
```

### 2d. Verify green & commit
```bash
swift test --package-path Packages/PTYTransport --filter ClientFrameTests
git add Packages/PTYTransport && git commit -m "feat(PTYTransport): ClientFrame JSON encoder, bug-compatible with ReconnectingPTYRequest"
```

---

## Step 3: URL builder (pure)

**File**: `Packages/PTYTransport/Sources/PTYTransport/Wire/URLBuilder.swift`

### 3a. Failing test
**File**: `Packages/PTYTransport/Tests/PTYTransportTests/Wire/URLBuilderTests.swift`

Cover: query order matches CLI (reconnect, width, height, command), wss:// scheme conversion, optional devcontainer params, empty-command always sent, baseURL with trailing slash.

### 3b. Run failing
```bash
swift test --package-path Packages/PTYTransport --filter URLBuilderTests
```

### 3c. Implement
```swift
import CoderAPI
import Foundation

/// Build the WebSocket URL for the PTY endpoint.
/// Source for shape + param order: .refs/coder/cli/exp_rpty.go:154 +
/// .refs/coder/codersdk/workspacesdk/workspacesdk.go:341
enum PTYURLBuilder {
    static func makeURL(deployment: Deployment, config: PTYTransportConfig) -> URL {
        let path = "/api/v2/workspaceagents/\(config.agentID.uuidString.lowercased())/pty"
        var c = URLComponents(url: deployment.baseURL.appendingPathComponent(path),
                              resolvingAgainstBaseURL: false)!
        var q: [URLQueryItem] = [
            .init(name: "reconnect", value: config.reconnectToken.uuidString.lowercased()),
            .init(name: "width",     value: String(config.initialSize.cols)),
            .init(name: "height",    value: String(config.initialSize.rows)),
            .init(name: "command",   value: config.command),
        ]
        if let v = config.container       { q.append(.init(name: "container",      value: v)) }
        if let v = config.containerUser   { q.append(.init(name: "container_user", value: v)) }
        if let v = config.backendType     { q.append(.init(name: "backend_type",   value: v.rawValue)) }
        c.queryItems = q
        c.scheme = c.scheme == "https" ? "wss" : "ws"
        return c.url!
    }
}
```

### 3d. Verify & commit
```bash
swift test --package-path Packages/PTYTransport --filter URLBuilderTests
git add Packages/PTYTransport && git commit -m "feat(PTYTransport): URL builder matching cli/exp_rpty.go param order"
```

---

## Step 4: `PTYTransportConfig` value type

**File**: `Packages/PTYTransport/Sources/PTYTransport/Models/PTYTransportConfig.swift`

Pure data; tested incidentally by URLBuilderTests. Add a `make(...)` convenience constructor for the common case (no container, no backend type).

### 4a-d. (Brief: TDD via existing URL tests; no new test file needed.)
Commit.

---

## Step 5: `ConnectionState` + `CloseReason` + `PTYError`

**Files**:
- `Packages/PTYTransport/Sources/PTYTransport/Models/ConnectionState.swift`
- `Packages/PTYTransport/Sources/PTYTransport/Models/CloseReason.swift`
- `Packages/PTYTransport/Sources/PTYTransport/Models/PTYError.swift`

### 5a. Failing test (state equality + transitions are non-trivial)
Cover Equatable conformance — `.reconnecting(attempt: 2, lastError: nil) == .reconnecting(attempt: 2, lastError: nil)` etc.

### 5b-e. TDD as Step 1.

---

## Step 6: `CloseClassifier` (pure)

**File**: `Packages/PTYTransport/Sources/PTYTransport/Wire/CloseClassifier.swift`

### 6a. Failing test
**File**: `Packages/PTYTransport/Tests/PTYTransportTests/Wire/CloseClassifierTests.swift`

```swift
// Source for codes: .refs/coder/coderd/workspaceapps/proxy.go:776,789 +
//                   .refs/coder/coderd/httpapi/websocket.go:53
final class CloseClassifierTests: XCTestCase {
    func test_normalClose_isUserInitiated() {
        XCTAssertEqual(
            CloseClassifier.classify(code: 1000, reason: ""),
            .userInitiated
        )
    }
    func test_goingAway_isServerTimeoutTransient() {
        XCTAssertEqual(
            CloseClassifier.classify(code: 1001, reason: "Ping failed"),
            .serverTimeout
        )
    }
    func test_internalError_dialAgent_classifiesAsAgentUnreachable() {
        XCTAssertEqual(
            CloseClassifier.classify(code: 1011, reason: "dial workspace agent: tailnet unreachable"),
            .agentUnreachable(detail: "dial workspace agent: tailnet unreachable")
        )
    }
    func test_internalError_otherDial_classifiesAsAgentUnreachable() {
        XCTAssertEqual(
            CloseClassifier.classify(code: 1011, reason: "dial: timeout"),
            .agentUnreachable(detail: "dial: timeout")
        )
    }
    func test_unauthorized_HTTPStatus401_classifiesAsAuthExpired() {
        XCTAssertEqual(
            CloseClassifier.classifyHTTPHandshake(status: 401),
            .authExpired
        )
    }
    func test_unknownCloseCode_isFatal() {
        XCTAssertEqual(
            CloseClassifier.classify(code: 1008, reason: "policy"),
            .fatal(code: 1008, reason: "policy")
        )
    }
}
```

### 6b-e. TDD.

---

## Step 7: `PTYTransport` protocol + namespace

**File**: `Packages/PTYTransport/Sources/PTYTransport/PTYTransport.swift`

Just the public protocol + factory protocol. No tests (it's a contract, not behavior).

### 7a-c. Define and commit.

---

## Step 8: `MockPTYTransport` (for downstream reducer tests)

**File**: `Packages/PTYTransport/Sources/PTYTransport/Mock/MockPTYTransport.swift`

A controllable fake: `simulateInbound(_ bytes: Data)`, `simulateState(_ state: ConnectionState)`, recording arrays for `sent: [Data]`, `resizes: [TerminalSize]`. Sendable via internal `Lock`-wrapped state.

### 8a-e. TDD with a self-test verifying recording semantics.

---

## Step 9: `EchoPTYServer` test harness

**File**: `Packages/PTYTransport/Tests/PTYTransportTests/Support/EchoPTYServer.swift`

`NWListener`-based localhost WebSocket server. Accepts a connection at `/api/v2/workspaceagents/{any-uuid}/pty?...`, parses query params, then plays a scripted sequence: send replay buffer, accept frames, send raw bytes, optionally close with a configurable code.

This is the hardest single piece. Estimated 4–6 implementation iterations. Allowed to be larger than 5 minutes; it underpins all subsequent live tests.

API:
```swift
final class EchoPTYServer {
    init(port: UInt16 = 0) async throws
    var url: URL { get }
    func script(_ steps: [Step])
    func waitForClient() async
    func close()

    enum Step {
        case send(Data)             // server → client
        case expect(ClientFrame)    // assert next client → server frame
        case close(code: UInt16, reason: String)
        case sleep(TimeInterval)
    }
}
```

### 9a-e. TDD: write a test that drives the server with a simple `script([.send("hi"), .close(code:1000, reason:"")])` and asserts via a raw `URLSessionWebSocketTask`.

---

## Step 10: `LivePTYTransport` skeleton — connect/send/recv (no reconnect yet)

**File**: `Packages/PTYTransport/Sources/PTYTransport/Live/LivePTYTransport.swift`

actor-based. On `connect()`: build URL, open `URLSessionWebSocketTask` with `Coder-Session-Token` header, receive loop in a child task, send queue drain in another. No reconnect logic — close just finishes streams.

### 10a. Failing test
Drive a script through `EchoPTYServer`, open a `LivePTYTransport`, assert `inbound` yields the scripted bytes; send a few `Data` payloads, assert server received them as JSON `{"data":...}`.

### 10b-e. TDD.

---

## Step 11: `LivePTYTransport.resize()`

### 11a. Failing test
After connect, resize to 50×200, assert next server-received frame is `{"height":50,"width":200}`.

### 11b-e. TDD.

---

## Step 12: Close handling — surface `CloseReason` via state stream

### 12a. Failing test
Server scripts `.close(code: 1011, reason: "dial workspace agent: ...")`. Assert state stream emits `.closed(.agentUnreachable(...))` and inbound stream finishes with `PTYError.closed(.agentUnreachable(...))`.

### 12b-e. TDD.

---

## Step 13: `Reconnector` — auto-reconnect on transient close

**File**: `Packages/PTYTransport/Sources/PTYTransport/Live/Reconnector.swift`

Pure orchestration: given a policy + a `dial: () async throws -> ()`, runs the loop with backoff/jitter. Honors cancellation. Surfaces attempt counts via callback.

### 13a. Failing test
Policy `(base: 0.01s, max: 0.05s, maxAttempts: 3)` against a dial that fails twice then succeeds. Use a `TestClock` (TCA's) — actually no, write a deterministic helper that doesn't use the system clock. Inject a `sleep: (TimeInterval) async throws -> ()` closure.

### 13b. Wire into `LivePTYTransport`: on transient close, schedule reconnect; emit `.reconnecting(attempt: N, lastError: ...)` then `.connecting(attempt: N+1)` then `.connected`. On `.userInitiated` / `.fatal` / `.authExpired`: don't retry.

### 13c-e. TDD with a script that closes the first connection with `1001 Ping failed`, reconnects, replays `Hello again` from the buffer, asserts inbound stream sees both pre- and post-reconnect bytes contiguous.

---

## Step 14: `LivePTYTransportFactory` + `@Dependency` registration

**File**: `Packages/PTYTransport/Sources/PTYTransport/PTYTransportFactory.swift`

Swift `Dependencies` library is already in use via TCA. Register:
```swift
private enum PTYTransportFactoryKey: DependencyKey {
    static let liveValue: any PTYTransportFactory = LivePTYTransportFactory()
    static let testValue: any PTYTransportFactory = MockPTYTransportFactory()
}
public extension DependencyValues {
    var ptyTransportFactory: any PTYTransportFactory {
        get { self[PTYTransportFactoryKey.self] }
        set { self[PTYTransportFactoryKey.self] = newValue }
    }
}
```

### 14a. Failing test: assert `@Dependency(\.ptyTransportFactory)` returns the mock under `withDependencies { $0.ptyTransportFactory = ... }`.

### 14b-e. Implement, verify, commit.

---

## Step 15: Coverage gate + lint clean

```bash
swift test --package-path Packages/PTYTransport --enable-code-coverage
# Inspect coverage; if < 85% on any source file, add targeted tests.
bin/check.sh lint  # SwiftFormat + SwiftLint
```

Commit any test-fill or lint fixes. **Stop and report if coverage misses gate** — don't paper over.

---

## Step 16: End-to-end smoke test

**File**: `Packages/PTYTransport/Tests/PTYTransportTests/Live/EndToEndTests.swift`

One test exercising the full flow:
1. `EchoPTYServer` configured with the golden frame trace from `apptest.go:2367-2426`
2. `LivePTYTransport` connects, receives "$ ", sends `"echo test\r"`, receives `"echo test\r\ntest\r\n$ "`, sends `"exit\r"`, server closes 1000.
3. Asserts state stream sequence `[.idle, .connecting(1), .connected, .closed(.userInitiated)]`.
4. Coverage check.

### 16a-e. TDD; this is the regression-protection test.

---

## Final commit + push

```bash
git log --oneline origin/main..HEAD   # review the run
git push origin main
```

Then we move to Step M2-2: TerminalUI (SwiftTerm wrapper).

---

## Notes for the executor

- **Always cite Coder source** (`.refs/coder/path:line`) in the doc comment whenever an implementation choice mirrors server behavior. Future maintainers should be able to re-verify in one click.
- **No client pings.** Don't be tempted to add a heartbeat. The server pings; URLSession answers. Adding one is a regression.
- **One JSON object per WS frame.** If multiple resizes pile up, send the latest as one frame, not several — server uses a streaming decoder but coalescing is cheaper.
- **`reconnectToken` is owned by the caller** (TerminalFeature), not the transport. The transport never generates one. This makes "open the same tab after backgrounding" trivial.
- **No buffering of stdin during reconnect.** UI disables input. If you find yourself wanting to buffer, re-read web UI behavior — it's deliberately a no.
