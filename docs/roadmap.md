# Roadmap

~8 weeks solo to App Store v1.0.

## M0 — Foundation (1 wk)

**Goal:** repo skeleton, CI green, paywall scaffold, no functional features yet.

- Tuist project + workspace
- Each SwiftPM package with empty target + a placeholder type + a passing test
- `.github/workflows/ci.yml` (build + test + lint matrix)
- `.swiftformat`, `.swiftlint.yml`, `lefthook.yml`
- ADRs 0001–0008 (initial set in [`adr/`](adr/))
- `App/` shell: launch → `StoreKitClient` check → paywall stub or login stub → empty workspace list
- `mise.toml` pinning toolchain versions
- Fastlane scaffold

**Exit criteria:** PR template enforces tests + lint, CI green on empty PR, app launches in simulator and shows paywall stub.

## M1 — Auth + Workspaces (1.5 wk)

**Goal:** sign in to a real Coder deployment, see real workspaces, control lifecycle.

- `CoderAPI`: auth methods discovery, login (password + token), workspace list, workspace detail, lifecycle (start/stop/restart), build log streaming
- `Auth`: OIDC via `ASWebAuthenticationSession` with PKCE, GitHub OAuth, password fallback, Keychain token storage, biometric gate
- `WorkspaceFeature`: list, detail, lifecycle actions, status SSE/poll
- Deployment switcher in Settings
- Custom CA upload flow on TLS failure

**Exit criteria:** OIDC + password login both work end-to-end on a real Coder deployment; can start/stop a workspace and watch build logs.

## M2 — Terminal MVP (2 wk)

**Goal:** working terminal with reconnecting PTY, key bar, devcontainer agents.

- `PTYTransport`: WebSocket connect, frame protocol, resize, heartbeat, reconnecting PTY with UUID
- `TerminalUI`: SwiftTerm wrapper, floating key bar (basic set), basic gestures (tap to keyboard, two-finger scroll)
- `TerminalFeature`: TCA reducer wiring transport ↔ UI, lifecycle, reconnect on disconnect
- iPad split-view shell (NavigationSplitView)
- Devcontainer / sub-agent rendering in workspace detail

**Exit criteria:** can open a terminal in a real workspace, type, get output, survive a 30s network drop with replayed scrollback.

## M3 — Polish (1.5 wk)

**Goal:** the app feels great, not just functional.

- Themes (Tokyo Night, Catppuccin, Solarized, Dracula, Gruvbox, custom JSON import)
- JetBrains Mono Nerd Font bundled
- Pinch-zoom font size
- Long-press selection with magnifier, copy/paste
- Multi-tab terminal within one workspace (swipe between)
- Multi-window on iPad
- Hardware keyboard polish: full UIKeyCommand menu
- Reorderable key bar
- Background opacity slider

**Exit criteria:** all UX-design.md interactions implemented, themes look right, hardware keyboard feels first-class on iPad.

## M4 — Quality (1 wk)

**Goal:** production-ready, beta-able.

- Snapshot test suite covering golden ANSI fixtures + every screen state
- Performance profiling: hit all targets in [performance.md](performance.md)
- Accessibility audit + fixes
- Privacy Manifest
- App Store metadata (description, keywords, categories)
- Screenshots for iPhone + iPad via Fastlane snapshot lane
- TestFlight beta with 20–50 users, collect feedback for 1wk

**Exit criteria:** all perf targets hit, no a11y blockers, TestFlight build approved, beta feedback triaged.

## M5 — Launch (1 wk)

**Goal:** v1.0 on App Store.

- App Store submission (likely 1–3 review rounds)
- Marketing site at `workspaceterminal.app` (Astro static, Cloudflare Pages)
- Support email + privacy policy hosted
- Public issues repo on GitHub: `workspaceterminal-issues`
- Launch announcement: Coder Discord, Hacker News, dev Twitter

**Exit criteria:** app live on App Store, marketing site up, first paying customers.

## Post-v1 candidates (not committed)

- macOS via Mac Catalyst
- visionOS spatial terminal
- Cloud sync of themes/settings (would justify a Pro subscription tier)
- File browser / SFTP-style file transfer to/from workspace
- Quick-action widgets (workspace status, start/stop)
- Shortcuts / App Intents integration
- watchOS companion (workspace status glance)
