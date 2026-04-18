import ComposableArchitecture
import Foundation
import PTYTransport
import TerminalUI

@Reducer
public struct TerminalFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let id: UUID
        public var size: TerminalSize
        public var connection: ConnectionState

        public init(id: UUID = UUID(), size: TerminalSize = TerminalSize(rows: 24, cols: 80)) {
            self.id = id
            self.size = size
            self.connection = .disconnected
        }
    }

    public enum ConnectionState: Sendable, Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting
    }

    public enum Action: Equatable {
        case onAppear
        case connectionChanged(ConnectionState)
        case resize(TerminalSize)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.connection = .connecting
                return .none
            case let .connectionChanged(connection):
                state.connection = connection
                return .none
            case let .resize(size):
                state.size = size
                return .none
            }
        }
    }
}
