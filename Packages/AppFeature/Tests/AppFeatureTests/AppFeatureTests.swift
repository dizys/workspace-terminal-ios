import ComposableArchitecture
import StoreKitClient
import Testing
@testable import AppFeature

@Suite("AppFeature smoke")
struct AppFeatureTests {
    @Test("Unentitled purchase status routes to paywall")
    @MainActor
    func unentitledRoutesToPaywall() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.purchaseStatusLoaded(.notPurchased)) {
            $0.purchaseStatus = .notPurchased
            $0.stage = .paywall
        }
    }

    @Test("Entitled purchase status routes to loggedOut (await login)")
    @MainActor
    func entitledRoutesToLoggedOut() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.purchaseStatusLoaded(.purchased(transactionID: 42))) {
            $0.purchaseStatus = .purchased(transactionID: 42)
            $0.stage = .loggedOut
        }
    }

    @Test("loginCompleted routes to loggedIn")
    @MainActor
    func loginCompletedRoutes() async {
        let store = TestStore(
            initialState: AppFeature.State(purchaseStatus: .purchased(transactionID: 1), stage: .loggedOut)
        ) {
            AppFeature()
        }
        await store.send(.loginCompleted) {
            $0.stage = .loggedIn
        }
    }
}
