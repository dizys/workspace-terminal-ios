import Foundation

/// Connection info for establishing a tailnet connection to a workspace agent.
///
/// Source: `.refs/coder/codersdk/workspacesdk/workspacesdk.go:143-148`
/// Endpoint: `GET /api/v2/workspaceagents/{id}/connection`
public struct AgentConnectionInfo: Sendable, Codable, Equatable {
    public let derpMap: DERPMap
    public let derpForceWebSockets: Bool
    public let disableDirectConnections: Bool
    public let hostnameSuffix: String?

    enum CodingKeys: String, CodingKey {
        case derpMap = "derp_map"
        case derpForceWebSockets = "derp_force_websockets"
        case disableDirectConnections = "disable_direct_connections"
        case hostnameSuffix = "hostname_suffix"
    }
}

/// DERP (Designated Encrypted Relay for Packets) map describing available
/// relay servers. The client connects to the nearest relay to forward
/// encrypted WireGuard packets when direct connections aren't possible.
///
/// Source: `.refs/coder/tailnet/proto/tailnet.proto:11-42` (protobuf)
/// + Tailscale's `tailcfg.DERPMap` (JSON serialization from REST endpoint)
public struct DERPMap: Sendable, Codable, Equatable {
    public let regions: [String: DERPRegion]

    enum CodingKeys: String, CodingKey {
        case regions = "Regions"
    }
}

public struct DERPRegion: Sendable, Codable, Equatable {
    public let regionID: Int
    public let embeddedRelay: Bool?
    public let regionCode: String
    public let regionName: String
    public let avoid: Bool?
    public let nodes: [DERPNode]

    enum CodingKeys: String, CodingKey {
        case regionID = "RegionID"
        case embeddedRelay = "EmbeddedRelay"
        case regionCode = "RegionCode"
        case regionName = "RegionName"
        case avoid = "Avoid"
        case nodes = "Nodes"
    }
}

public struct DERPNode: Sendable, Codable, Equatable, Identifiable {
    public let name: String
    public let regionID: Int
    public let hostName: String
    public let certName: String?
    public let ipv4: String?
    public let ipv6: String?
    public let stunPort: Int?
    public let stunOnly: Bool?
    public let derpPort: Int?
    public let insecureForTests: Bool?
    public let forceHTTP: Bool?
    public let canPort80: Bool?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case regionID = "RegionID"
        case hostName = "HostName"
        case certName = "CertName"
        case ipv4 = "IPv4"
        case ipv6 = "IPv6"
        case stunPort = "STUNPort"
        case stunOnly = "STUNOnly"
        case derpPort = "DERPPort"
        case insecureForTests = "InsecureForTests"
        case forceHTTP = "ForceHTTP"
        case canPort80 = "CanPort80"
    }

    /// The HTTPS URL to connect to this DERP node's relay WebSocket.
    public var derpURL: URL? {
        let scheme = (forceHTTP == true) ? "http" : "https"
        let port = derpPort ?? 443
        let portSuffix = (scheme == "https" && port == 443) || (scheme == "http" && port == 80) ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(hostName)\(portSuffix)/derp")
    }

    /// The WebSocket URL for DERP relay (used when derpForceWebSockets is true
    /// or as a fallback when raw TCP DERP isn't available).
    public var derpWSURL: URL? {
        let scheme = (forceHTTP == true) ? "ws" : "wss"
        let port = derpPort ?? 443
        let portSuffix = (scheme == "wss" && port == 443) || (scheme == "ws" && port == 80) ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(hostName)\(portSuffix)/derp")
    }
}
