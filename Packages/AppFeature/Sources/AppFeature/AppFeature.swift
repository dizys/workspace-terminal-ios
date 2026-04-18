import Auth
import CasePaths
import CoderAPI
import ComposableArchitecture
import Foundation
import StoreKitClient
import WorkspaceFeature

/// Top-level reducer. Composes:
///   - StoreKit purchase check (gates the app behind the paywall)
///   - DeploymentStore (active + known deployments persisted in Keychain)
///   - Auth flow (login screen when no active deployment)
///   - Workspaces (list + detail when signed in)
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var purchaseStatus: PurchaseStatus
        public var route: Route

        public init(purchaseStatus: PurchaseStatus = .unknown, route: Route = .launching) {
            self.purchaseStatus = purchaseStatus
            self.route = route
        }
    }

    @CasePathable
    public enum Route: Equatable {
        case launching
        case paywall
        case auth(AuthFeature.State)
        case signedIn(SignedInFeature.State)
    }

    public enum Action: Equatable {
        case appLaunched
        case purchaseStatusLoaded(PurchaseStatus)
        case activeDeploymentLoaded(StoredDeployment?)
        case auth(AuthFeature.Action)
        case signedIn(SignedInFeature.Action)
    }

    @Dependency(\.deploymentStore) var deploymentStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appLaunched:
                state.route = .launching
                return .run { send in
                    // 1. Check the purchase entitlement (stub for now).
                    await send(.purchaseStatusLoaded(.purchased(transactionID: 1)))
                    // 2. Load the active deployment from Keychain, if any.
                    let active = try? await deploymentStore.activeDeployment()
                    await send(.activeDeploymentLoaded(active))
                }

            case let .purchaseStatusLoaded(status):
                state.purchaseStatus = status
                if !status.isEntitled {
                    state.route = .paywall
                }
                return .none

            case let .activeDeploymentLoaded(stored):
                if let stored {
                    state.route = .signedIn(SignedInFeature.State(deployment: stored))
                } else if state.purchaseStatus.isEntitled {
                    state.route = .auth(AuthFeature.State())
                }
                return .none

            case let .auth(.signedIn(stored)):
                return .run { send in
                    try? await deploymentStore.upsertActive(stored)
                    await send(.activeDeploymentLoaded(stored))
                }

            case .signedIn(.signedOut):
                state.route = .auth(AuthFeature.State())
                return .none

            case .auth, .signedIn:
                return .none
            }
        }
        .ifCaseLet(\.route.auth, action: \.auth) {
            AuthFeature()
        }
        .ifCaseLet(\.route.signedIn, action: \.signedIn) {
            SignedInFeature()
        }
    }
}
