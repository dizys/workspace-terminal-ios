import CoderAPI
import ComposableArchitecture
import Foundation
import Testing
@testable import WorkspaceFeature

@Suite("WorkspaceListFeature")
struct WorkspaceListFeatureTests {
    @Test("onAppear → loaded(success) populates and sorts workspaces")
    @MainActor
    func loadsAndSorts() async {
        let unsortedFixture = [
            makeWorkspace(name: "zzz"),
            makeWorkspace(name: "aaa"),
        ]
        let pinnedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let store = TestStore(initialState: WorkspaceListFeature.State()) {
            WorkspaceListFeature()
        } withDependencies: {
            $0.authenticatedAPIClient = .init(make: {
                FakeClient(workspaces: unsortedFixture)
            })
            $0.date = .constant(pinnedNow)
        }
        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(.loaded(.success(unsortedFixture))) {
            $0.isLoading = false
            $0.workspaces = unsortedFixture.sorted(by: { $0.name < $1.name })
            $0.lastFetchedAt = pinnedNow
        }
    }

    @Test("onAppear with no client surfaces 'Not signed in' error")
    @MainActor
    func noClient() async {
        let store = TestStore(initialState: WorkspaceListFeature.State()) {
            WorkspaceListFeature()
        } withDependencies: {
            $0.authenticatedAPIClient = .init(make: { nil })
        }
        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.loaded.failure) {
            $0.isLoading = false
            $0.error = "Not signed in"
        }
    }
}

private func makeWorkspace(name: String) -> Workspace {
    let now = Date()
    let job = ProvisionerJob(id: UUID(), status: .succeeded, createdAt: now)
    let build = WorkspaceBuild(
        id: UUID(),
        workspaceID: UUID(),
        workspaceName: name,
        workspaceOwnerID: UUID(),
        workspaceOwnerName: "alice",
        templateVersionID: UUID(),
        buildNumber: 1,
        transition: .start,
        initiatorID: UUID(),
        initiatorName: "alice",
        job: job,
        createdAt: now,
        updatedAt: now
    )
    return Workspace(
        id: UUID(),
        name: name,
        ownerID: UUID(),
        ownerName: "alice",
        templateID: UUID(),
        templateName: "ubuntu",
        createdAt: now,
        updatedAt: now,
        latestBuild: build
    )
}

private struct FakeClient: CoderAPIClient {
    let workspaces: [Workspace]
    let deployment = Deployment(baseURL: URL(string: "https://x")!, displayName: "x")

    func fetchAuthMethods() async throws -> AuthMethods { fatalError() }
    func login(email: String, password: String) async throws -> SessionToken { fatalError() }
    func fetchCurrentUser() async throws -> User { fatalError() }
    func logout() async throws {}
    func fetchBuildInfo() async throws -> BuildInfo { fatalError() }
    func listMyWorkspaces() async throws -> [Workspace] { workspaces }
    func fetchWorkspace(id: UUID) async throws -> Workspace { fatalError() }
    func createBuild(workspaceID: UUID, transition: WorkspaceBuild.Transition) async throws -> WorkspaceBuild { fatalError() }
    func fetchBuild(id: UUID) async throws -> WorkspaceBuild { fatalError() }
    func streamBuildLogs(buildID: UUID, follow: Bool) async throws -> AsyncThrowingStream<BuildLog, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
