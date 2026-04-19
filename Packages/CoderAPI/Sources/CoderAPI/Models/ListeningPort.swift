import Foundation

/// A TCP port currently being listened on inside a workspace agent.
/// Returned by `GET /api/v2/workspaceagents/{id}/listening-ports`.
///
/// Source: `.refs/coder/codersdk/workspaceagents.go:394-398`
public struct ListeningPort: Sendable, Hashable, Codable, Identifiable {
    public let processName: String
    public let network: String
    public let port: UInt16

    public var id: UInt16 { port }

    public init(processName: String = "", network: String = "tcp", port: UInt16) {
        self.processName = processName
        self.network = network
        self.port = port
    }

    enum CodingKeys: String, CodingKey {
        case processName = "process_name"
        case network
        case port
    }

    /// Human-friendly label for common dev ports.
    public var portHint: String? {
        switch port {
        case 3000: return "React / Next.js"
        case 3001: return "Next.js (alt)"
        case 4200: return "Angular"
        case 5173: return "Vite"
        case 5174: return "Vite (alt)"
        case 8000: return "Django / FastAPI"
        case 8080: return "HTTP"
        case 8081: return "HTTP (alt)"
        case 8443: return "HTTPS"
        case 8888: return "Jupyter"
        case 9000: return "PHP / MinIO"
        case 4000: return "Phoenix"
        case 5000: return "Flask"
        case 5432: return "PostgreSQL"
        case 6379: return "Redis"
        case 27017: return "MongoDB"
        default: return nil
        }
    }
}

struct ListeningPortsResponse: Codable {
    let ports: [ListeningPort]
}

/// A listening port annotated with which agent it belongs to.
/// Used in the UI to disambiguate when multiple agents listen on the
/// same port number.
public struct AgentPort: Sendable, Hashable, Identifiable {
    public let port: ListeningPort
    public let agentID: UUID
    public let agentName: String

    public var id: String { "\(agentID.uuidString):\(port.port)" }

    public init(port: ListeningPort, agentID: UUID, agentName: String) {
        self.port = port
        self.agentID = agentID
        self.agentName = agentName
    }
}
