import CoderAPI
import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct WorkspaceListFeature {
    @ObservableState
    public struct State: Equatable {
        public var deployment: Deployment?
        public var workspaces: [WorkspaceSummary] = []
        public var isLoading = false

        public init(deployment: Deployment? = nil) {
            self.deployment = deployment
        }
    }

    public enum Action: Equatable {
        case onAppear
        case refresh
        case workspacesLoaded([WorkspaceSummary])
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear, .refresh:
                state.isLoading = true
                return .none
            case let .workspacesLoaded(workspaces):
                state.workspaces = workspaces
                state.isLoading = false
                return .none
            }
        }
    }
}

public struct WorkspaceSummary: Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let name: String
    public let status: Status

    public enum Status: Sendable, Equatable, Hashable {
        case running
        case stopped
        case starting
        case stopping
        case failed
    }

    public init(id: UUID, name: String, status: Status) {
        self.id = id
        self.name = name
        self.status = status
    }
}
