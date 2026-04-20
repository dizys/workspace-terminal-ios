import CoderAPI
import ComposableArchitecture
import Foundation
import PTYTransport

/// Container for multiple `TerminalFeature` tabs against the same agent
/// (multi-terminal-per-workspace, per M2 roadmap). Each tab has its own
/// reconnect token and its own `TerminalSession` in the store.
@Reducer
public struct TerminalSessionsFeature {
    @ObservableState
    public struct State: Equatable, Sendable {
        public let agent: WorkspaceAgent
        public let deployment: Deployment
        public var tabs: IdentifiedArrayOf<TerminalFeature.State>
        public var selectedID: TerminalFeature.State.ID?

        public init(
            agent: WorkspaceAgent,
            deployment: Deployment,
            tabs: IdentifiedArrayOf<TerminalFeature.State> = [],
            selectedID: TerminalFeature.State.ID? = nil
        ) {
            self.agent = agent
            self.deployment = deployment
            self.tabs = tabs
            self.selectedID = selectedID
        }
    }

    public enum Action: Equatable, Sendable {
        case onAppear
        case addTabTapped
        case restartTabTapped(TerminalFeature.State.ID)
        case closeTabTapped(TerminalFeature.State.ID)
        case selectTab(TerminalFeature.State.ID?)
        case tabs(IdentifiedActionOf<TerminalFeature>)
    }

    @Dependency(\.terminalSessionStore) var sessionStore
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.tabs.isEmpty {
                    let tab = TerminalFeature.State(agent: state.agent, deployment: state.deployment)
                    state.tabs.append(tab)
                    state.selectedID = tab.sessionID
                }
                return .none

            case .addTabTapped:
                let tab = TerminalFeature.State(agent: state.agent, deployment: state.deployment)
                state.tabs.append(tab)
                state.selectedID = tab.sessionID
                return .none

            case let .restartTabTapped(id):
                guard let index = state.tabs.index(id: id) else { return .none }
                let size = state.tabs[index].size
                let replacement = TerminalFeature.State(
                    agent: state.agent,
                    deployment: state.deployment,
                    size: size
                )
                state.tabs.remove(id: id)
                state.tabs.insert(replacement, at: min(index, state.tabs.count))
                state.selectedID = replacement.sessionID

                let store = sessionStore
                return .run { _ in
                    if let session = await store.session(for: id) {
                        await session.close(.userInitiated)
                    }
                    await store.detach(id: id)
                }

            case let .closeTabTapped(id):
                guard let index = state.tabs.index(id: id) else { return .none }
                let wasSelected = state.selectedID == id
                state.tabs.remove(id: id)
                if wasSelected {
                    if state.tabs.isEmpty {
                        state.selectedID = nil
                    } else {
                        // Prefer the previous tab; fall back to first.
                        let newIndex = max(0, index - 1)
                        state.selectedID = state.tabs[safe: newIndex]?.sessionID
                            ?? state.tabs.first?.sessionID
                    }
                }
                // Tear down the underlying TerminalSession (closes its
                // PTY transport) — explicit user intent to close the tab.
                let store = sessionStore
                let shouldDismiss = state.tabs.isEmpty
                let dismiss = self.dismiss
                return .run { _ in
                    if let session = await store.session(for: id) {
                        await session.close(.userInitiated)
                    }
                    await store.detach(id: id)
                    if shouldDismiss {
                        await dismiss()
                    }
                }

            case let .selectTab(id):
                state.selectedID = id
                return .none

            case .tabs:
                return .none
            }
        }
        .forEach(\.tabs, action: \.tabs) {
            TerminalFeature()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension IdentifiedArray {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
