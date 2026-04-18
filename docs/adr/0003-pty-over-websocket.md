# ADR-0003: PTY over WebSocket (no SSH for v1)

- **Status:** Accepted
- **Date:** 2026-04-17

## Context

Coder workspaces can be reached two ways from a client:

1. **PTY-over-WebSocket** via Coder's `/api/v2/workspaceagents/{id}/pty` endpoint. Authenticated via Coder session token. Works through Coder's own networking (DERP, wireguard mesh).
2. **SSH** via Coder's `coder ssh` proxy or direct wireguard. Requires an SSH client implementation on iOS, key management, and bypasses Coder's auth in favor of SSH keys.

Power users may want SSH for full keybinding fidelity, port forwarding, and `scp`-style file transfer.

## Decision

**Ship PTY-over-WebSocket only for v1.** No SSH client.

## Consequences

**Positive:**
- One transport to implement, test, and debug.
- Reuses Coder's auth flow (OIDC, session tokens) — no separate SSH key management UX.
- Reuses Coder's reconnecting-PTY for network resilience.
- Works through Coder's networking abstractions (DERP, wireguard) without us needing to implement them.
- Devcontainer sub-agents are first-class via the same endpoint.

**Negative:**
- Some power-user workflows (port forwarding, `scp`) are not possible.
- WebSocket framing has slightly more overhead than raw TCP+SSH.
- If Coder changes the PTY protocol, we have to follow.

**Mitigations:**
- Document the limitation in App Store description.
- Revisit SSH support in post-v1 if user demand justifies it. ADR supersedes this one when it happens.
