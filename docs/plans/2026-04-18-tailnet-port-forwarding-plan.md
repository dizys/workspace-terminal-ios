# Plan: Tailnet Port Forwarding (Coder-Native, No VPN)

**Goal**: Forward arbitrary TCP ports from a Coder workspace agent to the iOS device without requiring wildcard DNS, VPN entitlements, or Tailscale accounts. Use Coder's own coordination + DERP relay infrastructure with userspace WireGuard.

**Architecture**: 
- WebSocket to coderd `/api/v2/workspaceagents/{id}/coordinate` → yamux → dRPC → protobuf coordination
- Coder's DERP relay server forwards encrypted WireGuard packets over WebSocket
- `wireguard-apple` userspace tunnel (in-process, no NEPacketTunnelProvider)
- `Network.framework` NWListener exposes forwarded port on `127.0.0.1:<random>`
- WKWebView in-app browser points at the local listener

**Tech Stack**: Swift 6, Network.framework, wireguard-apple (MIT), swift-protobuf, URLSessionWebSocketTask

**Source-of-truth references**:
- `.refs/coder/tailnet/proto/tailnet.proto` — protobuf schema for coordination
- `.refs/coder/codersdk/workspacesdk/dialer.go` — WebSocket dialer + dRPC setup
- `.refs/coder/codersdk/workspacesdk/workspacesdk.go:200-280` — DialAgent flow
- `.refs/coder/codersdk/workspacesdk/agentconn.go:316` — DialContext (TCP through tunnel)
- `.refs/coder/tailnet/conn.go` — WireGuard + netstack setup

## Protocol Stack (from Coder Go source)

```
iOS App                          coderd                        Agent
  |                                |                             |
  |-- WS /coordinate ------------>|                             |
  |   (yamux + dRPC)              |                             |
  |<-- DERPMap (relay servers) ---|                             |
  |-- CoordinateRequest -------->|-- forward to agent -------->|
  |   (my WG pubkey, tunnel req) |                             |
  |<-- CoordinateResponse -------|<-- agent's WG pubkey -------|
  |                                                             |
  |-- DERP relay WebSocket ---------------------------------->  |
  |   (encrypted WG packets      relayed by coderd)             |
  |<-- DERP relay WebSocket ----------------------------------|
  |                                                             |
  | [WireGuard tunnel established]                              |
  |                                                             |
  |-- TCP dial localhost:port ------[through WG tunnel]-------->|
  |<-- TCP data ----------------[through WG tunnel]------------|
```

## Implementation Layers

| Layer | Package | Description | Sessions |
|-------|---------|-------------|----------|
| 1 | CoderAPI | Connection info + DERP map fetch | 0.5 |
| 2 | TailnetClient | Protobuf models + dRPC-over-yamux-over-WS | 1.5 |
| 3 | TailnetClient | DERP relay client (WS packet forwarding) | 1 |
| 4 | TailnetClient | WireGuard userspace tunnel via wireguard-apple | 1 |
| 5 | PortForwarding | NWListener bridge + TCP dial through tunnel | 0.5 |
| 6 | BrowserKit | WKWebView in-app browser + integration | 0.5 |

## Step 1: Connection Info API (Layer 1)

**Files**: 
- `Packages/CoderAPI/Sources/CoderAPI/Models/AgentConnectionInfo.swift`
- `Packages/CoderAPI/Sources/CoderAPI/Endpoints/ConnectionInfoEndpoints.swift`

Fetch `GET /api/v2/workspaceagents/{id}/connection-info` which returns:
```json
{
  "derp_map": { "regions": { ... } },
  "derp_force_websockets": true,
  "disable_direct_connections": false
}
```

Source: `.refs/coder/codersdk/workspacesdk/workspacesdk.go:143-168`

## Step 2: Protobuf Models (Layer 2)

**Files**: `Packages/TailnetClient/Sources/TailnetClient/Proto/`

Generate Swift protobuf from `tailnet.proto` or hand-write the subset we need:
- `DERPMap` (regions → nodes with hostnames + ports)
- `Node` (WireGuard key, preferred DERP, addresses)
- `CoordinateRequest` (UpdateSelf, Tunnel, ReadyForHandshake)
- `CoordinateResponse` (PeerUpdate with agent's Node)

## Step 3: dRPC-over-Yamux-over-WebSocket (Layer 2)

**Files**: `Packages/TailnetClient/Sources/TailnetClient/Coordination/`

The Go client does:
1. `websocket.Dial(coordinateURL)` → binary WebSocket
2. `websocket.NetConn(ws)` → wraps as net.Conn
3. `yamux.Client(netConn)` → multiplexer
4. `drpc.NewConn(yamuxStream)` → RPC client
5. `client.Coordinate()` → bidirectional stream
6. `client.StreamDERPMaps()` → receive DERP map updates

We need a Swift yamux + minimal dRPC implementation. Yamux is a simple multiplexer protocol (8-byte header + payload). dRPC is even simpler than gRPC — just length-prefixed protobuf frames over a stream.

## Step 4: DERP Relay Client (Layer 3)

**Files**: `Packages/TailnetClient/Sources/TailnetClient/DERP/`

DERP is a simple WebSocket relay:
1. Connect to the DERP server URL from the DERPMap
2. Send: `[1-byte type][payload]` frames
3. Type 0x04 = SendPacket (to a specific peer by WG pubkey)
4. Type 0x05 = RecvPacket (from a peer)
5. Relay just forwards encrypted WireGuard packets between peers

Source: Tailscale's DERP protocol (open, well-documented).

## Step 5: WireGuard Userspace Tunnel (Layer 4)

**Dependencies**: `wireguard-apple` SPM package

1. Generate ephemeral WireGuard key pair
2. Send our public key to coderd via CoordinateRequest.UpdateSelf
3. Receive agent's public key via CoordinateResponse.PeerUpdate
4. Configure wireguard-apple userspace tunnel:
   - Our private key
   - Agent's public key as peer
   - Endpoint = DERP relay (packets routed through DERP)
   - AllowedIPs = agent's Tailscale IP (fd7a:115c:a1e0::/48 prefix)
5. Tunnel runs entirely in-process — no VPN, no entitlement

## Step 6: TCP Bridge + Browser (Layers 5-6)

**Files**: 
- `Packages/PortForwarding/Sources/PortForwarding/PortBridge.swift`
- `Packages/BrowserKit/Sources/BrowserKit/WTBrowserView.swift`

1. User taps a port → create a `NWListener` on `127.0.0.1:<random>`
2. On each inbound connection, dial `agent-ip:port` through the WireGuard tunnel
3. Bidirectional byte pump (same pattern as EchoPTYServer)
4. Point `WKWebView` at `http://127.0.0.1:<random>`
5. On tab close, tear down listener + tunnel connections

## Task Dependencies

| Group | Steps | Can Parallelize |
|-------|-------|-----------------|
| 1 | Step 1 (Connection Info API) | Independent |
| 2 | Step 2 (Protobuf models) | Independent, can run with Group 1 |
| 3 | Step 3 (dRPC/yamux/WS) | Depends on Group 2 |
| 4 | Step 4 (DERP client) | Depends on Group 3 |
| 5 | Step 5 (WireGuard tunnel) | Depends on Groups 3+4 |
| 6 | Step 6 (TCP bridge + browser) | Depends on Group 5 |
| 7 | End-to-end verification | Depends on all |

## Risks

1. **wireguard-apple compatibility**: Need to verify the userspace API works without NEPacketTunnelProvider on iOS 17+.
2. **yamux + dRPC in Swift**: No existing Swift libraries; we implement minimal versions (~200 lines each).
3. **DERP protocol changes**: Pin to Coder's specific DERP implementation, not generic Tailscale.
4. **App Store review**: Userspace WireGuard should be fine (no VPN entitlement), but novel networking patterns sometimes trigger manual review.
