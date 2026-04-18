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
        await store.send(.onAppear) {
            #expect($0.tabs.count == 1)
            $0.selectedID = $0.tabs.first!.sessionID
        }
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
        await store.send(.addTabTapped) {
            #expect($0.tabs.count == 2)
            $0.selectedID = $0.tabs.last!.sessionID
        }
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
