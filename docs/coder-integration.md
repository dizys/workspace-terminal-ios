# Coder Integration

> All endpoint paths and shapes here are based on Coder's public OSS API as of writing. Re-verify against the current OpenAPI spec at `https://<deployment>/api/v2/swagger.json` before implementation.

## Auth methods discovery

`GET /api/v2/users/authmethods` returns which auth methods the deployment has enabled:

```json
{
  "password": { "enabled": true },
  "github":   { "enabled": true },
  "oidc":     { "enabled": true, "signInText": "Login with Okta", "iconUrl": "..." }
}
```

Login screen renders only the buttons for enabled methods.

## OIDC

- Use `ASWebAuthenticationSession`.
- Custom URL scheme registered in `Info.plist`: `workspaceterminal://auth/callback`.
- PKCE with S256 code challenge, 43+ character verifier.
- `prefersEphemeralWebBrowserSession = false` by default (enterprise SSO usually expects cookie reuse). User can opt into ephemeral mode in Settings.
- On callback, exchange code for session token via Coder's OIDC callback endpoint, store token in Keychain.

### Custom CA caveat

Many self-hosted Coder deployments use OIDC providers behind custom internal CAs. `ASWebAuthenticationSession` runs in the Safari sandbox and respects only system trust. **Users with custom CAs must install them via iOS Configuration Profile**. Document this in the support page; show a clear error if OIDC redirect fails with TLS error.

## Workspaces

- `GET /api/v2/users/me/workspaces` (or `GET /api/v2/workspaces?owner=me`) — list user's workspaces.
- Poll on a 30s interval when list is visible, plus pull-to-refresh.
- Optional: subscribe to SSE stream of workspace updates if available on the deployment.

### Lifecycle

- `POST /api/v2/workspaces/{id}/builds` with `transition: "start" | "stop"` to control workspace.
- Stream build logs from `GET /api/v2/workspacebuilds/{buildId}/logs?follow=true` while transitioning.

## Agents

- A workspace has one or more **agents** (one per resource in the template).
- The workspace detail response includes agents nested under resources.
- Each agent has: id, name, status (`connecting` / `connected` / `disconnected` / `timeout`), OS, arch, version, lifecycle state.

### Devcontainer / docker-in-docker

Coder's devcontainer integration spawns **sub-agents** (one per running devcontainer inside the workspace). They appear in the agent list once the devcontainer is up.

- Workspace detail shows: parent agent + each child (devcontainer) agent.
- User taps any agent to open its terminal.
- Show agent type badge: `host` vs `devcontainer`.

## PTY (the core feature)

`GET /api/v2/workspaceagents/{agentId}/pty` upgraded to WebSocket.

Query params:
- `reconnect={uuid}` — stable per logical terminal session
- `height={rows}` — initial PTY rows
- `width={cols}` — initial PTY cols

Frame protocol:
- **Binary frames** carry raw PTY bytes (stdout from server; stdin to server).
- **Text frames** carry resize JSON: `{"height": N, "width": N}`.

Heartbeat: send `ping` text frame every ~25s to keep proxies happy.

### Reconnecting PTY

- Generate one UUID per terminal tab on creation, hold in memory for the tab's lifetime.
- On disconnect (network blip, app backgrounding), reconnect with the same UUID.
- Server replays buffered output (Coder buffers ~1MB of recent PTY output per reconnect token).
- Background app: keep WebSocket alive ~30s via background URLSession; after that, allow disconnection but show "Reconnecting…" overlay on resume.

### Resize

Send a text frame `{"height": rows, "width": cols}` whenever:
- Terminal view bounds change (rotation, keyboard show/hide, split-screen resize)
- User pinch-zooms font size

Debounce to ~16ms so rapid layout changes don't flood the server.

## Auth headers

Coder uses the `Coder-Session-Token` header for authenticated API calls. Never use cookies on the native side — cookie behavior across `URLSession` and `ASWebAuthenticationSession` is messy. Persist the session token from OIDC callback in Keychain and attach the header explicitly to every request.

## Cert handling

- `URLSessionDelegate` with optional pinned cert and per-deployment "trust this CA" flow.
- User-supplied CA stored in Keychain alongside the deployment record.
- Trust evaluation in `urlSession(_:didReceive:completionHandler:)`.
