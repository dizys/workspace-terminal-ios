import ComposableArchitecture
import Testing
@testable import WorkspaceFeature
import Foundation

@Suite("WorkspaceListFeature smoke")
struct WorkspaceListFeatureTests {
    @Test("onAppear flips isLoading to true")
    @MainActor
    func onAppearLoading() async {
        let store = TestStore(initialState: WorkspaceListFeature.State()) {
            WorkspaceListFeature()
        }
        await store.send(.onAppear) {
            $0.isLoading = true
        }
    }

    @Test("workspacesLoaded clears loading and stores workspaces")
    @MainActor
    func workspacesLoaded() async {
        let store = TestStore(initialState: WorkspaceListFeature.State(deployment: nil)) {
            WorkspaceListFeature()
        }
        let one = WorkspaceSummary(id: UUID(), name: "dev", status: .running)
        await store.send(.refresh) { $0.isLoading = true }
        await store.send(.workspacesLoaded([one])) {
            $0.isLoading = false
            $0.workspaces = [one]
        }
    }
}
