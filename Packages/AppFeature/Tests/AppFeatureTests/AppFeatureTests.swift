import Auth
import CoderAPI
import ComposableArchitecture
import Foundation
import StoreKitClient
import Testing
@testable import AppFeature

@Suite("AppFeature smoke")
struct AppFeatureTests {
    @Test("appLaunched routes to auth when no active deployment + entitled")
    @MainActor
    func launchesToAuth() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.deploymentStore = DeploymentStoreDependency(
                LiveDeploymentStore(keychain: InMemoryKeychainClient())
            )
        }
        store.exhaustivity = .off
        await store.send(.appLaunched)
        await store.receive(.purchaseStatusLoaded(.purchased(transactionID: 1)))
        await store.receive(.activeDeploymentLoaded(nil))
        #expect({ if case .auth = store.state.route { return true } else { return false } }())
    }

    @Test("appLaunched routes to signedIn when an active deployment exists")
    @MainActor
    func launchesToSignedIn() async throws {
        let kc = InMemoryKeychainClient()
        let live = LiveDeploymentStore(keychain: kc)
        let stored = StoredDeployment(
            deployment: Deployment(baseURL: URL(string: "https://x.example.com")!, displayName: "x"),
            token: SessionToken("tok")
        )
        try await live.upsertActive(stored)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.deploymentStore = DeploymentStoreDependency(live)
        }
        store.exhaustivity = .off
        await store.send(.appLaunched)
        await store.receive(.purchaseStatusLoaded(.purchased(transactionID: 1)))
        await store.receive(\.activeDeploymentLoaded)
        #expect({ if case .signedIn = store.state.route { return true } else { return false } }())
    }
}
