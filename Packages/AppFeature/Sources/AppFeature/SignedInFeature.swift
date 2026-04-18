import Auth
import CoderAPI
import ComposableArchitecture
import Foundation
import TerminalFeature
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
        @Presents public var terminals: TerminalSessionsFeature.State?
        /// App-level cache: live `TerminalSessionsFeature.State` per agent.id.
        /// Survives navigation back/forward so reopening an agent restores
        /// existing tabs (and the underlying TerminalSessions in the
        /// TerminalSessionStore stay alive via `.onDisappear` no-op).
        public var activeTerminals: [UUID: TerminalSessionsFeature.State] = [:]

        public init(deployment: StoredDeployment) {
            self.deployment = deployment
            self.workspaceList = WorkspaceListFeature.State()
        }

        /// Map of agent.id → number of cached live tabs. Used to badge
        /// agents in the workspace detail view.
        public var liveSessionsByAgent: [UUID: Int] {
            Dictionary(uniqueKeysWithValues: activeTerminals.map { ($0.key, $0.value.tabs.count) })
        }
    }

    public enum Action: Equatable {
        case workspaceList(WorkspaceListFeature.Action)
        case detail(WorkspaceDetailFeature.Action)
        case openTerminal(WorkspaceAgent)
        case killAgentSessions(UUID)
        case terminals(PresentationAction<TerminalSessionsFeature.Action>)
        case settingsButtonTapped
        case settingsDismissed
        case signOutTapped
        case signedOut
    }

    @Dependency(\.deploymentStore) var deploymentStore
    @Dependency(\.terminalSessionStore) var terminalSessionStore

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

            case let .openTerminal(agent):
                // Restore existing tabs if user previously opened this agent
                // and didn't close everything. Otherwise create a fresh state.
                if let cached = state.activeTerminals[agent.id] {
                    state.terminals = cached
                } else {
                    state.terminals = TerminalSessionsFeature.State(
                        agent: agent,
                        deployment: state.deployment.deployment
                    )
                }
                return .none

            case .terminals(.dismiss):
                // User navigated back. Snapshot the live state into our cache
                // so reopening the agent restores the same tabs.
                if let current = state.terminals {
                    if current.tabs.isEmpty {
                        // Last tab closed via shell exit / × → forget the cache
                        state.activeTerminals.removeValue(forKey: current.agent.id)
                    } else {
                        state.activeTerminals[current.agent.id] = current
                    }
                }
                return .none

            case let .killAgentSessions(agentID):
                // Tear down every cached session for this agent. Used when
                // the user explicitly ends sessions from the agent list.
                guard let cached = state.activeTerminals.removeValue(forKey: agentID) else {
                    return .none
                }
                let tabIDs = cached.tabs.map(\.sessionID)
                let store = terminalSessionStore
                return .run { _ in
                    for id in tabIDs {
                        if let session = await store.session(for: id) {
                            await session.close(.userInitiated)
                        }
                        await store.detach(id: id)
                    }
                }

            case .terminals:
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
        .ifLet(\.$terminals, action: \.terminals) {
            TerminalSessionsFeature()
        }
    }
}
