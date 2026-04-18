# Testing Strategy

## Pyramid

```
       ╱╲
      ╱UI╲          XCUITest, golden paths only (~10 tests)
     ╱────╲
    ╱ Snap ╲        Snapshot tests for terminal rendering + screens (~50)
   ╱────────╲
  ╱Integration╲     Local Coder via Docker, full flows (~20)
 ╱────────────╲
╱──────Unit────╲    Reducers, clients, encoders, framers (~500)
```

## Unit

- **CoderAPI**: `URLProtocol` stub injected via `URLSessionConfiguration.protocolClasses`. Each endpoint has happy path + error variants (401, 404, 500, network failure, malformed JSON).
- **PTYTransport**: in-process WebSocket echo server (`Network.framework` `NWListener`). Verify framing, resize JSON, reconnect with replay, heartbeat.
- **Auth**: PKCE generation determinism (with injected RNG), token storage round-trip via fake Keychain, OIDC callback URL parsing.
- **TCA reducers**: every action transition with `TestStore`. No real network, no real time — `Clock` is `TestClock`.

## Property tests

- ANSI passthrough: random bytes round-trip through SwiftTerm without panic or memory growth.
- Key encoding: every (key, modifier-set) tuple encodes to a deterministic byte sequence matching xterm reference.

## Snapshot tests

- Use [`swift-snapshot-testing`](https://github.com/pointfreeco/swift-snapshot-testing).
- Terminal rendering: feed golden ANSI fixtures (recorded `vim`, `htop`, `tmux`, `lazygit`, `btop` sessions), snapshot the resulting view at 3 fixed sizes.
- Screens: workspace list (empty / 1 workspace / many / loading / error), terminal connection states (connecting / connected / reconnecting / disconnected), settings.
- Run on a fixed simulator (iPhone 15 Pro, iPad Pro 12.9") to avoid device-rendering drift.

## Integration

- GitHub Actions spins up `coder/coder` Docker image.
- Test seeds a workspace template, user, OIDC dev provider (Dex).
- XCTest hits the running Coder, runs login → list → start workspace → open PTY → send command → verify output → stop.
- Catches API drift between Coder versions.

## UI

- XCUITest for golden paths only:
  - First-run: launch → paywall → mock purchase → login → empty state
  - Login → workspace list → tap workspace → terminal connects → type `echo hi` → see output
  - Settings → switch deployment → verify list reloads
- Avoid testing every UI permutation — snapshot tests cover that better.

## Accessibility

- VoiceOver smoke test in XCUITest: navigate every non-terminal screen with accessibility.
- Dynamic Type: snapshot screens at smallest + largest sizes.
- Contrast: automated check on every theme via `UIColor` luminance comparison.

## Coverage gates

| Package | Minimum line coverage |
|---|---|
| `CoderAPI` | 85% |
| `PTYTransport` | 85% |
| `Auth` | 85% |
| `TerminalFeature` (reducer) | 80% |
| `WorkspaceFeature` (reducer) | 80% |
| Other packages | 60% |

Enforced via `xccov` in CI; PR fails if coverage drops below gate.
