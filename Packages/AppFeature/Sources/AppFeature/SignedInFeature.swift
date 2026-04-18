import Auth
import CoderAPI
import ComposableArchitecture
import Foundation
import WorkspaceFeature

/// State and reducer for the signed-in surface: workspace list + selected
/// workspace detail + settings sheet.
@Reducer
public struct SignedInFeature {
    @ObservableState
    public struct State: Equatable {
        public var deployment: StoredDeployment
        public var workspaceList: WorkspaceListFeature.State
        public var selectedWorkspaceID: UUID?
        public var detail: WorkspaceDetailFeature.State?
        public var isSettingsPresented: Bool = false

        public init(deployment: StoredDeployment) {
            self.deployment = deployment
            self.workspaceList = WorkspaceListFeature.State()
        }
    }

    public enum Action: Equatable {
        case workspaceList(WorkspaceListFeature.Action)
        case detail(WorkspaceDetailFeature.Action)
        case settingsButtonTapped
        case settingsDismissed
        case signOutTapped
        case signedOut
    }

    @Dependency(\.deploymentStore) var deploymentStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.workspaceList, action: \.workspaceList) {
            WorkspaceListFeature()
        }

        Reduce { state, action in
            switch action {
            case let .workspaceList(.workspaceTapped(id)):
                state.selectedWorkspaceID = id
                let summary = state.workspaceList.workspaces.first(where: { $0.id == id })
                state.detail = WorkspaceDetailFeature.State(workspaceID: id, workspace: summary)
                return .none

            case .workspaceList:
                return .none

            case .detail:
                return .none

            case .settingsButtonTapped:
                state.isSettingsPresented = true
                return .none

            case .settingsDismissed:
                state.isSettingsPresented = false
                return .none

            case .signOutTapped:
                let id = state.deployment.id
                let store = deploymentStore
                return .run { send in
                    try? await store.remove(id: id)
                    await send(.signedOut)
                }

            case .signedOut:
                return .none
            }
        }
        .ifLet(\.detail, action: \.detail) {
            WorkspaceDetailFeature()
        }
    }
}
