import Foundation

/// Coder server's reconnecting-PTY backend selector.
///
/// `nil` (omit the query param) lets the server pick its default. The two
/// supported values come from `agent/reconnectingpty/reconnectingpty.go:69-91`
/// in the upstream Go source (`.refs/coder/`).
public enum BackendType: String, Sendable, Codable, CaseIterable, Equatable {
    case buffered
    case screen
}
