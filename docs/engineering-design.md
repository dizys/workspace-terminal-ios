# Engineering Design

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| Language | **Swift 6**, strict concurrency on | Long-term Apple direction; data-race safety |
| UI | **SwiftUI** + **UIKit** interop | SwiftUI for screens; UIKit hosts SwiftTerm and the floating key bar where we need precise control |
| State | **The Composable Architecture (TCA)** | Predictable state, testable reducers, time-travel debugging worth the ceremony at this complexity |
| Terminal emulator | **SwiftTerm** (Miguel de Icaza) | Production-grade native xterm; CSI/SGR/OSC, true color, mouse, sixel, image protocol |
| WebSocket | **URLSessionWebSocketTask** | First-party, no third-party WS lib |
| Auth (OIDC) | **ASWebAuthenticationSession** | First-party, respects system trust + cookies |
| Credentials | **Keychain Services** + **CryptoKit** | Standard secure storage |
| Logging | **swift-log** + **os.Logger** with redacting formatter | Performance + privacy |
| StoreKit | **StoreKit 2** | Receipt validation via `Transaction.currentEntitlements` |
| Project gen | **Tuist** | Deterministic `.xcodeproj`; eliminates merge conflicts |
| Lint/format | **SwiftFormat** + **SwiftLint** + **lefthook** | Consistent style, pre-commit gates |

## Module layout (SwiftPM, monorepo)

```
App/                      ← thin shell, DI composition root, scene setup
Packages/
  CoderAPI/               ← REST client, codable models, error taxonomy, OIDC discovery
  PTYTransport/           ← reconnecting WS, framing, resize, heartbeat
  Auth/                   ← OIDC (ASWebAuthenticationSession), token store, biometric gate
  TerminalUI/             ← SwiftTerm wrapper, key bar, gestures, hw-keyboard handling
  WorkspaceFeature/       ← TCA: list, detail, lifecycle, devcontainer agents
  TerminalFeature/        ← TCA: per-tab terminal state + PTY effect wiring
  AppFeature/             ← TCA: composition, deployment switcher, scene management
  StoreKitClient/         ← receipt validation, paid-tier gate
  DesignSystem/           ← themes, Nerd Font bundle, primitives, iPad layout helpers
  TestSupport/            ← fakes, fixtures, snapshot helpers
  # added at M3.5 (port forwarding + in-app browser)
  PortForwarding/         ← protocol + dual-mode (subdomain proxy / loopback bridge)
  LoopbackBridge/         ← Network.framework NWListener + WS-to-TCP pump
  BrowserKit/             ← WKWebView wrapper, address bar, port picker, reader-mode
  BrowserFeature/         ← TCA reducer for the browser tab
```

**Why split this finely:** each package builds and tests in isolation. `CoderAPI` and `PTYTransport` could ship as standalone reusable libraries (future macOS / visionOS clients). The App target is just composition — easy to reason about.

## Layered architecture

```
┌─────────────────────────────────────────────┐
│  Presentation (SwiftUI Views)               │
├─────────────────────────────────────────────┤
│  Feature Modules (TCA Reducers/Stores)      │
│  - AppFeature, WorkspaceFeature, TerminalFeature │
├─────────────────────────────────────────────┤
│  Domain (Use Cases, Models)                 │
├─────────────────────────────────────────────┤
│  Data (CoderAPI, PTYTransport, Auth, KeychainClient) │
├─────────────────────────────────────────────┤
│  Infrastructure (URLSession, WebSocket,     │
│   SwiftTerm, Logger, StoreKit)              │
└─────────────────────────────────────────────┘
```

## Data flow — terminal session

```
KeyEvent ─┐
KeyBarTap ┼─► TerminalReducer ─► PTYTransport.send(bytes)
GestureKey┘                                 │
                                            ▼
                               URLSessionWebSocketTask
                                            │
                                            ▼
                       PTYTransport.frames AsyncStream
                                            │
                                            ▼
                          TerminalReducer ─► SwiftTerm.feed(bytes)
                                            │
                                            ▼
                                       Renderer → screen
```

## TCA reducer shape

```swift
// Top-level
@Reducer
struct AppFeature {
  @ObservableState
  struct State {
    var deployment: DeploymentState        // .none, .loggingIn, .authenticated(Deployment, Token)
    var workspaces: WorkspacesFeature.State?
    var settings: SettingsFeature.State
    var hasPurchased: Bool
  }
  enum Action {
    case appLaunched
    case deployment(DeploymentAction)
    case workspaces(WorkspacesFeature.Action)
    case settings(SettingsFeature.Action)
    case storeKit(StoreKitClient.Action)
  }
}

// Per-terminal
@Reducer
struct TerminalFeature {
  @ObservableState
  struct State: Identifiable {
    let id: UUID                    // == reconnect token
    let agent: Agent
    var connection: ConnectionState // .connecting, .connected, .reconnecting, .disconnected(reason)
    var size: TerminalSize
    var scrollbackBytes: Int
    var keyBarConfig: KeyBarConfig
  }
  enum Action {
    case onAppear
    case received(Data)             // bytes from PTY
    case input(InputEvent)          // key events from UI
    case resize(TerminalSize)
    case connectionChanged(ConnectionState)
    case ptyClient(PTYClient.Action) // long-lived effect
  }
}
```

- **Long-running effects** as `EffectOf` with `.cancellable(id: TerminalID)` — clean shutdown when a tab closes.
- **Dependency injection** via `@Dependency` — `CoderAPIClient`, `PTYClientFactory`, `KeychainClient`, `Clock` all injectable for tests.
- **Side-effect-free reducers** + thin SwiftUI views = trivial to snapshot-test entire screens.

## Concurrency model

- `URLSession` calls wrapped in `async throws` methods on `CoderAPIClient` (a `Sendable` struct).
- `PTYTransport` exposes `AsyncThrowingStream<Frame, Error>` for inbound; `func send(_:) async throws` for outbound.
- TCA effects bridge `AsyncStream` → reducer actions via `.run`.
- Actors only where shared mutable state crosses task boundaries (e.g. `DeploymentStore`, `KeychainClient`).
- `@MainActor` on view models / SwiftUI surfaces.

## Error handling

- Typed errors per package (`CoderAPIError`, `PTYError`, `AuthError`).
- Top-level reducer maps errors to user-facing `ErrorPresentation` enum (toast / sheet / blocking).
- All network errors carry context: HTTP status, server message, retry-after, correlation ID if present.
- No silent failures — every error reaches a Logger and either UI or an explicit "ignored because X" log line.
