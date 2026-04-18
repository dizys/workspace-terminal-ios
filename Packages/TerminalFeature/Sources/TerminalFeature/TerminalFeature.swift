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
        public let id: UUID
        public let agent: WorkspaceAgent
        public let deployment: Deployment
        public var size: TerminalSize
        public var connection: Phase
        public var totalBytesReceived: Int
        public var lastError: String?

        public init(
            id: UUID = UUID(),
            agent: WorkspaceAgent,
            deployment: Deployment,
            size: TerminalSize = TerminalSize(rows: 24, cols: 80)
        ) {
            self.id = id
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
                let id = state.id
                let agent = state.agent
                let deployment = state.deployment
                let size = state.size
                let factory = transportFactory
                let store = sessionStore
                let tokens = tokenProvider

                return .run { send in
                    // Build a transport scoped to this tab's reconnect token.
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
                    let session = TerminalSession(id: id, agent: agent, transport: transport)
                    await store.attach(id: id, session: session)

                    // Pump the session's connection-state stream into actions.
                    // Bytes deliberately NOT pumped here — see header comment.
                    do {
                        try await session.connect()
                    } catch {
                        await send(.errorRaised("connect failed: \(error)"))
                        return
                    }
                    for await s in session.state {
                        await send(.stateChanged(s))
                    }
                }
                .cancellable(id: CancelID.statePump(id), cancelInFlight: true)

            case .onDisappear:
                let id = state.id
                let store = sessionStore
                return .merge(
                    .cancel(id: CancelID.statePump(id)),
                    .run { _ in
                        if let session = await store.session(for: id) {
                            await session.close(.userInitiated)
                        }
                        await store.detach(id: id)
                    }
                )

            case .userInputSent:
                return .none

            case let .resize(size):
                state.size = size
                let id = state.id
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
        case .userInitiated:                                    return "userInitiated"
        case let .agentUnreachable(detail):                     return "agentUnreachable: \(detail)"
        case .authExpired:                                      return "authExpired"
        case .serverTimeout:                                    return "serverTimeout"
        case let .fatal(code, message):                         return "fatal(\(code)): \(message)"
        }
    }
}
