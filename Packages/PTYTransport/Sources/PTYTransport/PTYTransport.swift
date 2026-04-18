import Foundation

/// Reconnecting WebSocket transport for the Coder PTY endpoint.
public enum PTYTransport {
    public static let defaultHeartbeatInterval: TimeInterval = 25
}

public struct TerminalSize: Sendable, Equatable, Codable {
    public let rows: Int
    public let cols: Int

    public init(rows: Int, cols: Int) {
        precondition(rows > 0 && cols > 0, "Terminal size must be positive")
        self.rows = rows
        self.cols = cols
    }
}
