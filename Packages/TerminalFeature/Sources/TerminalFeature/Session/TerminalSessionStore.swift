import Foundation

/// Per-app registry of live terminal sessions, keyed by reconnect token.
///
/// The View layer (`WTTerminalView`) and the TCA reducer both look up the
/// active session through this store rather than holding a direct reference,
/// which lets SwiftUI re-create views without disturbing transport state and
/// keeps the reducer's `State` Equatable-friendly.
public actor TerminalSessionStore {
    private var sessions: [UUID: TerminalSession] = [:]

    public init() {}

    public func attach(id: UUID, session: TerminalSession) {
        sessions[id] = session
    }

    public func detach(id: UUID) {
        sessions.removeValue(forKey: id)
    }

    public func session(for id: UUID) -> TerminalSession? {
        sessions[id]
    }

    public var allSessions: [TerminalSession] {
        Array(sessions.values)
    }
}
