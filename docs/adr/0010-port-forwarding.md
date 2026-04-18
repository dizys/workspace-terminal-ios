# ADR-0010: Dual-mode port forwarding (subdomain proxy + loopback WebSocket bridge)

- **Status:** Accepted
- **Date:** 2026-04-18

## Context

Mobile developers need to view services running inside their Coder workspace from their phone — dev servers, internal UIs, dashboards, Jupyter notebooks. Coder's existing web dashboard supports port forwarding via subdomain proxy, but it lives in Safari, which contradicts the "first-class native" pillar.

We need port forwarding + an in-app browser to view the forwarded services.

Considered transport options:

1. **Subdomain proxy only** — easy, zero local code, but requires admin to have configured wildcard apps. Not universal.
2. **Loopback WebSocket bridge only** — universal, more code, slightly slower. Wraps Coder's `/api/v2/workspaceagents/{id}/connect/{port}` WebSocket and exposes it on `127.0.0.1:<random>`.
3. **Tailscale / wireguard** — true mesh networking. Powerful but requires a `NEPacketTunnelProvider` entitlement, complicates App Store review, and pulls in significant networking surface area.
4. **Dual-mode (1 + 2 with auto-select)** — best of both. Try subdomain first, fall back to loopback.

## Decision

**Dual-mode: subdomain proxy preferred, loopback WebSocket bridge as fallback.** No Tailscale/wireguard for v1.

Mode selection happens transparently at the moment the user taps a port. The user sees a single "Open" button, not two.

## Consequences

**Positive:**
- Universal coverage — works on every Coder deployment regardless of admin config.
- App-Store-clean — no VPN / network-extension entitlements.
- Performance: most users hit the subdomain fast path.
- Same auth model as PTY (session token over WebSocket) — no new credentials surface.
- Progressive disclosure — the user doesn't have to understand which mode is active unless they want to.

**Negative:**
- Two transport implementations to maintain.
- Loopback bridge is non-trivial: per-connection async stream-to-stream pump with backpressure, error mapping, lifecycle tied to browser tab.
- iOS suspends WebSockets in background — tunnels need transparent reconnect on foreground.

**Mitigations:**
- Both transports live behind a single `PortForwarding` protocol so feature code is mode-agnostic.
- Reuse `PTYTransport`'s reconnect machinery — same problem, same solution.
- Loopback listener bound strictly to `127.0.0.1` (not `0.0.0.0`); release the local port when the tab closes.
- DevTools-lite panel surfaces tunnel state visually so the user can diagnose hot-reload weirdness without us hiding the abstraction entirely.

## Alternatives considered

- **Mode 1 only (subdomain only)**: simpler but excludes deployments without wildcard apps. Rejected — leaves real users out.
- **Mode 2 only (loopback only)**: universal but slower for the common case where Mode 1 is available. Rejected — worse default UX for the majority.
- **Tailscale / wireguard**: more capable, but the App Store entitlement story and runtime complexity are not worth it for v1. Revisit post-v1 if there's demand for non-HTTP forwarding (Postgres clients, Redis CLI, etc.) and a credible plan to ship matching native iOS clients.

## Implementation surface

New SwiftPM packages targeted at M3.5:

- `PortForwarding/` — protocol + both transport implementations
- `LoopbackBridge/` — `Network.framework` `NWListener` + WebSocket pump (extracted because it's reusable for non-HTTP forwarding later)
- `BrowserKit/` — `WKWebView` wrapper, DevTools-lite, address bar, port picker, JSON/HTML reader-mode
- `BrowserFeature/` — TCA reducer for the browser tab, integrating `PortForwarding` + `BrowserKit`

The browser shares the same multi-tab shell as the terminal — switching between a terminal tab and a browser tab in the same workspace should be one swipe, not a context loss.
