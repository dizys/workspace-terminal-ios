import CoderAPI
import ComposableArchitecture
import Foundation
import Testing
@testable import TerminalFeature

@Suite("TerminalSessionsFeature reducer", .serialized)
@MainActor
struct TerminalSessionsFeatureTests {
    private func makeAgent() -> WorkspaceAgent {
        WorkspaceAgent(
            id: UUID(),
            name: "main",
            status: .connected,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeDeployment() -> Deployment {
        Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: "test")
    }

    @Test("onAppear seeds the first tab and selects it")
    func onAppearSeedsFirstTab() async {
        let store = TestStore(
            initialState: TerminalSessionsFeature.State(
                agent: makeAgent(),
                deployment: makeDeployment()
            )
        ) {
            TerminalSessionsFeature()
        }
        store.exhaustivity = .off
        await store.send(.onAppear)
        #expect(store.state.tabs.count == 1)
        #expect(store.state.selectedID == store.state.tabs.first?.sessionID)
    }

    @Test("addTabTapped appends a new tab and selects it")
    func addTabAppendsAndSelects() async {
        var initial = TerminalSessionsFeature.State(
            agent: makeAgent(),
            deployment: makeDeployment()
        )
        // Pre-seed one tab so we can test appending against existing state.
        let firstTab = TerminalFeature.State(agent: initial.agent, deployment: initial.deployment)
        initial.tabs.append(firstTab)
        initial.selectedID = firstTab.sessionID

        let store = TestStore(initialState: initial) {
            TerminalSessionsFeature()
        }
        store.exhaustivity = .off
        await store.send(.addTabTapped)
        #expect(store.state.tabs.count == 2)
        #expect(store.state.selectedID == store.state.tabs.last?.sessionID)
    }

    @Test("closeTabTapped removes a tab; selection moves to remaining tab")
    func closeTabReassignsSelection() async {
        var initial = TerminalSessionsFeature.State(
            agent: makeAgent(),
            deployment: makeDeployment()
        )
        let a = TerminalFeature.State(agent: initial.agent, deployment: initial.deployment)
        let b = TerminalFeature.State(agent: initial.agent, deployment: initial.deployment)
        initial.tabs.append(a)
        initial.tabs.append(b)
        initial.selectedID = b.sessionID

        let store = TestStore(initialState: initial) {
            TerminalSessionsFeature()
        }
        // Closing the selected tab should move selection to a sibling.
        await store.send(.closeTabTapped(b.sessionID)) {
            $0.tabs.remove(id: b.sessionID)
            $0.selectedID = a.sessionID
        }
    }

    @Test("closeTabTapped on the last tab leaves selection nil")
    func closeLastTabLeavesNil() async {
        var initial = TerminalSessionsFeature.State(
            agent: makeAgent(),
            deployment: makeDeployment()
        )
        let only = TerminalFeature.State(agent: initial.agent, deployment: initial.deployment)
        initial.tabs.append(only)
        initial.selectedID = only.sessionID

        let store = TestStore(initialState: initial) {
            TerminalSessionsFeature()
        }
        await store.send(.closeTabTapped(only.sessionID)) {
            $0.tabs.remove(id: only.sessionID)
            $0.selectedID = nil
        }
    }

    @Test("closed session stays visible instead of closing the tab")
    func closedSessionStaysVisible() async {
        var initial = TerminalSessionsFeature.State(
            agent: makeAgent(),
            deployment: makeDeployment()
        )
        let only = TerminalFeature.State(agent: initial.agent, deployment: initial.deployment)
        initial.tabs.append(only)
        initial.selectedID = only.sessionID

        let store = TestStore(initialState: initial) {
            TerminalSessionsFeature()
        }
        await store.send(.tabs(.element(id: only.sessionID, action: .stateChanged(.closed(.serverTimeout))))) {
            $0.tabs[id: only.sessionID]?.connection = .closed(
                reasonDescription: "This terminal session expired while the app was away."
            )
            $0.selectedID = only.sessionID
        }
    }

    @Test("restartTabTapped replaces the stale tab with a fresh session")
    func restartTabReplacesStaleSession() async {
        var initial = TerminalSessionsFeature.State(
            agent: makeAgent(),
            deployment: makeDeployment()
        )
        let stale = TerminalFeature.State(agent: initial.agent, deployment: initial.deployment)
        initial.tabs.append(stale)
        initial.selectedID = stale.sessionID
        initial.tabs[id: stale.sessionID]?.connection = .closed(
            reasonDescription: "This terminal session expired while the app was away."
        )

        let store = TestStore(initialState: initial) {
            TerminalSessionsFeature()
        }
        store.exhaustivity = .off
        await store.send(.restartTabTapped(stale.sessionID))
        #expect(store.state.tabs.count == 1)
        #expect(store.state.tabs.first?.sessionID != stale.sessionID)
        #expect(store.state.selectedID == store.state.tabs.first?.sessionID)
    }

    @Test("selectTab updates selectedID")
    func selectTabUpdates() async {
        var initial = TerminalSessionsFeature.State(
            agent: makeAgent(),
            deployment: makeDeployment()
        )
        let a = TerminalFeature.State(agent: initial.agent, deployment: initial.deployment)
        let b = TerminalFeature.State(agent: initial.agent, deployment: initial.deployment)
        initial.tabs.append(a)
        initial.tabs.append(b)
        initial.selectedID = a.sessionID

        let store = TestStore(initialState: initial) {
            TerminalSessionsFeature()
        }
        await store.send(.selectTab(b.sessionID)) {
            $0.selectedID = b.sessionID
        }
    }
}
