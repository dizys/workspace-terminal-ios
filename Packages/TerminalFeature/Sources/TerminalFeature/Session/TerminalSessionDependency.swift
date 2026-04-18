import ComposableArchitecture
import Foundation

/// `@Dependency(\.terminalSessionStore)` wiring. One store per app instance
/// (live), one fresh per test (test value).
extension TerminalSessionStore: DependencyKey {
    public static let liveValue = TerminalSessionStore()
    public static var testValue: TerminalSessionStore { TerminalSessionStore() }
}

extension DependencyValues {
    public var terminalSessionStore: TerminalSessionStore {
        get { self[TerminalSessionStore.self] }
        set { self[TerminalSessionStore.self] = newValue }
    }
}
