# Port Forwarding & In-App Browser

> Targeted at M3.5. See [roadmap.md](roadmap.md). Strategy ratified in [ADR-0010](adr/0010-port-forwarding.md).

## Problem

Developers running services inside their Coder workspace — local HTTP dev servers, Node apps, Vite/Next dev servers, Streamlit/Gradio, Storybook, Jupyter, internal admin UIs — should be able to open those services from their iPhone or iPad as easily as from their laptop. Without this, the app is half a workstation.

The Coder web dashboard already supports port forwarding via subdomain proxy, but mobile users hit it from Safari, which is missing from a "first-class native experience" claim.

## Solution: dual-mode forwarding + native in-app browser

Two transport modes, auto-selected per deployment, behind a single user-facing API.

### Mode A — Subdomain proxy (preferred when available)

Coder deployments configured with a wildcard hostname (`app_hostname` setting on the server, e.g. `*.apps.coder.example.com`) automatically expose every TCP port in a workspace at:

```
https://<port>--<agent-name>--<workspace-name>--<owner>.apps.coder.example.com
```

Our app:

1. Reads `app_hostname` from `GET /api/v2/buildinfo`.
2. Constructs the URL from workspace + agent + port.
3. Opens it in our in-app `WKWebView`.
4. Injects the `Coder-Session-Token` cookie scoped to the apps domain so the user is auto-authenticated.

**Pros:** zero local sockets, works through Coder's existing networking abstractions, no VPN entitlement, App-Store-clean.

**Cons:** requires admin to have configured wildcard apps. Many self-hosted deployments do; some don't.

### Mode B — WebSocket tunnel + loopback bridge (universal fallback)

Coder exposes `GET /api/v2/workspaceagents/{id}/connect/{port}` as a WebSocket that tunnels arbitrary TCP traffic. Our app:

1. Starts a tiny TCP listener on `127.0.0.1:<random-port>` via `Network.framework` (`NWListener`).
2. Per inbound TCP connection, opens a Coder PTY-style WebSocket (`/api/v2/workspaceagents/{id}/connect/{port}`).
3. Bridges bytes loopback ↔ WebSocket bidirectionally.
4. Points the in-app browser at `http://127.0.0.1:<random-port>`.

**Pros:** universal — works on every Coder deployment regardless of admin config. Same auth model as PTY (session token over WebSocket). Loopback `Network.framework` listeners are explicitly App-Store-allowed (no `NEPacketTunnelProvider` entitlement, no VPN, no network extension).

**Cons:** more code to maintain. ~5–20ms perf overhead from the local hop (not noticeable for HTTP browsing).

### Mode selection

```swift
enum PortForwardingMode {
    case subdomain(URL)          // Mode A — direct https://port--agent--workspace--owner.apps.<host>
    case loopback(URL)           // Mode B — http://127.0.0.1:<random>
}

func resolveForwarding(workspace: Workspace, agent: Agent, port: Int) async throws -> PortForwardingMode {
    if let appHost = await deploymentInfo.appHostname {
        return .subdomain(buildSubdomainURL(host: appHost, workspace: workspace, agent: agent, port: port))
    }
    return .loopback(try await loopbackBridge.start(workspace: workspace, agent: agent, port: port))
}
```

The user never sees the mode — they tap a port, the browser opens the right URL.

## Port discovery

Coder exposes `GET /api/v2/workspaceagents/{id}/listening-ports` which returns all TCP ports the agent's processes are listening on, including process names. Poll on a 5s interval while the workspace detail screen is visible. Show:

- Port number
- Detected process (e.g. `node`, `python`, `cargo`, `rails`)
- Common port hint (3000 → "React/Next dev server", 5173 → "Vite", 8080 → "HTTP", 5432 → "Postgres", etc.)

User can also enter an arbitrary port manually if the auto-discovery missed it.

## In-app browser (`WebKit`-based, dev-tuned)

A `WKWebView` wrapper purpose-built for inspecting forwarded services. Not a Safari clone — a developer's browser.

### Features

- **Address bar with port picker** — combobox showing discovered ports + history.
- **DevTools-lite panel** (slide-up):
  - Network requests log (URL, method, status, time, size) using `WKURLSchemeHandler` interception
  - Console messages (`window.console.*` proxied via `WKScriptMessageHandler`)
  - Response headers + body inspector
  - Cookies for the current host
- **Reader-mode for JSON / HTML** — pretty-print structured responses with collapsible trees and syntax highlighting.
- **Hot-reload friendly** — auto-reconnect WebSockets on disconnect; transparently retry HTTP on tunnel restart.
- **Self-signed cert tolerance for `127.0.0.1`** — accept the loopback's self-issued cert without prompting.
- **Tab switcher** alongside terminal tabs — same multi-tab UX.
- **Cookie/session auth injection** — automatic for subdomain mode (Coder session token cookie scoped to apps host).
- **iPad split-view: terminal on one side, browser on the other.** Killer combo: edit in terminal, refresh in browser, no tab dance.
- **Pull-to-refresh, back/forward gestures, find-in-page.**
- **External-browser handoff** — "Open in Safari" if user wants a real browser.

### Out of scope for v1

- Browser extensions / userscripts
- Picture-in-picture for video
- Any general-purpose browsing (this is for forwarded ports + maybe local docs)
- WebRTC, getUserMedia (no camera/mic permissions requested)

## What's NOT solved by this

- **Non-HTTP TCP from iOS** (e.g., connecting a Postgres CLI from iOS to the workspace's Postgres on port 5432): the loopback bridge *can* expose the TCP socket on `127.0.0.1`, but iOS doesn't ship a general-purpose Postgres CLI. Useful only if a future feature in the app speaks that protocol natively.
- **UDP forwarding**: not supported by Coder's WebSocket tunnel. Out of scope.
- **Background tunnels**: iOS suspends WebSockets after ~30s in background, same as PTY. Tunnels reconnect on foreground.
- **Multicast / mDNS**: not relevant for forwarded workspace services.

## Security & privacy

- Session token never sent to non-Coder hosts; cookie injection scoped strictly to the deployment's apps hostname.
- Loopback listener bound to `127.0.0.1` only (never `0.0.0.0`).
- Loopback random port chosen per session, released on browser tab close.
- Browser cookies + cache are partitioned per workspace; closing the workspace clears them.
- "Allow loopback HTTPS with self-signed cert" only applies to literal `127.0.0.1`; never auto-trusts other hosts.
- DevTools-lite logs are local to the device; never uploaded.

## Performance budget

| Metric | Target |
|---|---|
| Subdomain-mode TTI (tap port → first paint) | <600ms warm, <1.5s cold |
| Loopback-mode TTI | <900ms warm, <2.5s cold (extra WS handshake) |
| Loopback per-byte overhead | <2ms (in-process bridge) |
| Memory per active tunnel | <5MB |
| Concurrent tunnels supported | 8 (more on iPad) |

## Testing

- **Unit:** mode-selection logic, URL construction, cookie scoping, port-discovery polling.
- **Integration:** spin up a workspace with a known HTTP server (`python -m http.server`), verify both modes deliver the response.
- **Snapshot:** browser chrome at multiple sizes.
- **Manual:** test against a real React dev server, Vite, Next.js, Streamlit, FastAPI to verify hot-reload survives tunnel hiccups.
