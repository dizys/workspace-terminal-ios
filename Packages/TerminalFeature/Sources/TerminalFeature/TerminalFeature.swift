import CoderAPI
import ComposableArchitecture
import Foundation
import PTYTransport
import TerminalUI

/// One terminal tab: lifecycle of the PTY session + UI state.
///
/// Bytes do **not** flow through this reducer — `WTTerminalView` subscribes
/// to the underlying `TerminalSession.inbound` directly and feeds SwiftTerm
/// without round-tripping through the action loop. The reducer only tracks
/// *count* (for diagnostics + UI badges) and the connection phase.
@Reducer
public struct TerminalFeature {
    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        /// Stable identifier for the tab; doubles as the PTY reconnect token.
        /// Named `sessionID` (not `id`) to avoid colliding with `Store`'s own
        /// `Identifiable.id: ObjectIdentifier`, which shadows dynamic lookup.
        public let sessionID: UUID
        public let agent: WorkspaceAgent
        public let deployment: Deployment
        public var size: TerminalSize
        public var connection: Phase
        public var totalBytesReceived: Int
        public var lastError: String?

        public var id: UUID { sessionID }

        public init(
            sessionID: UUID = UUID(),
            agent: WorkspaceAgent,
            deployment: Deployment,
            size: TerminalSize = TerminalSize(rows: 24, cols: 80)
        ) {
            self.sessionID = sessionID
            self.agent = agent
            self.deployment = deployment
            self.size = size
            self.connection = .idle
            self.totalBytesReceived = 0
        }

        public enum Phase: Sendable, Equatable {
            case idle
            case connecting(attempt: Int)
            case connected
            case reconnecting(attempt: Int)
            case closed(reasonDescription: String)
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case onDisappear
        case userInputSent             // bytes already forwarded by view; reducer just notes
        case resize(TerminalSize)
        case bytesReceived(count: Int)
        case stateChanged(ConnectionState)
        case errorRaised(String)
        case dismissError
    }

    @Dependency(\.ptyTransportFactory) var transportFactory
    @Dependency(\.terminalSessionStore) var sessionStore
    @Dependency(\.authenticatedSessionToken) var tokenProvider

    public init() {}

    private enum CancelID: Hashable { case statePump(UUID) }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let id = state.sessionID
                let agent = state.agent
                let deployment = state.deployment
                let size = state.size
                let factory = transportFactory
                let store = sessionStore
                let tokens = tokenProvider

                return .run { send in
                    // Idempotent: SwiftUI may re-mount off-screen tabs and
                    // refire .task → .onAppear. If a session already exists
                    // for this sessionID, re-subscribe to its state stream
                    // instead of creating a new transport (which would
                    // replace + deinit the old session, breaking subscribers).
                    let session: TerminalSession
                    if let existing = await store.session(for: id) {
                        session = existing
                    } else {
                        let config = PTYTransportConfig(
                            agentID: agent.id,
                            reconnectToken: id,
                            initialSize: size
                        )
                        let transport = factory(
                            deployment: deployment,
                            tls: .default,
                            config: config,
                            tokenProvider: { await tokens() }
                        )
                        let new = TerminalSession(id: id, agent: agent, transport: transport)
                        await store.attach(id: id, session: new)
                        do {
                            try await new.connect()
                        } catch {
                            await send(.errorRaised("connect failed: \(error)"))
                            return
                        }
                        session = new
                    }

                    // Pump the session's connection-state stream into actions.
                    // Bytes deliberately NOT pumped here — see header comment.
                    for await s in session.state {
                        await send(.stateChanged(s))
                    }
                }
                .cancellable(id: CancelID.statePump(id), cancelInFlight: true)

            case .onDisappear:
                // SwiftUI's TabView unmounts off-screen tabs; firing close
                // here would tear down the session and re-mounting would
                // start a fresh one (blank). Just cancel the state-pump
                // effect; the session itself stays in the store and gets
                // torn down explicitly via .closeTabTapped on the parent
                // feature, or on full feature dismissal.
                return .cancel(id: CancelID.statePump(state.sessionID))

            case .userInputSent:
                return .none

            case let .resize(size):
                state.size = size
                let id = state.sessionID
                let store = sessionStore
                return .run { _ in
                    if let session = await store.session(for: id) {
                        try? await session.resize(size)
                    }
                }

            case let .bytesReceived(count):
                state.totalBytesReceived &+= count
                return .none

            case let .stateChanged(connectionState):
                state.connection = phase(for: connectionState)
                return .none

            case let .errorRaised(message):
                state.lastError = message
                return .none

            case .dismissError:
                state.lastError = nil
                return .none
            }
        }
    }

    private func phase(for state: ConnectionState) -> State.Phase {
        switch state {
        case .idle:                                 return .idle
        case let .connecting(attempt):              return .connecting(attempt: attempt)
        case .connected:                            return .connected
        case let .reconnecting(attempt, _):         return .reconnecting(attempt: attempt)
        case let .closed(reason):                   return .closed(reasonDescription: describe(reason))
        }
    }

    private func describe(_ reason: CloseReason) -> String {
        switch reason {
        case .userInitiated:
            return "Terminal closed."
        case let .agentUnreachable(detail):
            return "The workspace agent is unreachable. \(detail)"
        case .authExpired:
            return "Your Coder session expired. Sign in again."
        case .serverTimeout:
            return "This terminal session expired while the app was away."
        case let .fatal(code, message):
            return "Connection failed (\(code)): \(message)"
        }
    }
}
