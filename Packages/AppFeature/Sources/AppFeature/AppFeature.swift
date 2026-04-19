import Auth
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
///
/// Routing is modeled as a `Phase` enum + optional substates rather than a
/// single `Route` enum. This avoids the `@Reducer enum` ceremony for cases
/// that have no associated reducer (`.launching`, `.paywall`) while still
/// supporting `.ifLet`-style child-reducer composition.
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var purchaseStatus: PurchaseStatus
        public var phase: Phase
        public var auth: AuthFeature.State?
        public var signedIn: SignedInFeature.State?

        public init(purchaseStatus: PurchaseStatus = .unknown, phase: Phase = .launching) {
            self.purchaseStatus = purchaseStatus
            self.phase = phase
        }
    }

    public enum Phase: Sendable, Equatable {
        case launching
        case paywall
        case auth
        case signedIn
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
                state.phase = .launching
                let store = deploymentStore
                return .run { send in
                    await send(.purchaseStatusLoaded(.purchased(transactionID: 1)))
                    let active = try? await store.activeDeployment()
                    await send(.activeDeploymentLoaded(active))
                }

            case let .purchaseStatusLoaded(status):
                state.purchaseStatus = status
                if !status.isEntitled {
                    state.phase = .paywall
                    state.auth = nil
                    state.signedIn = nil
                }
                return .none

            case let .activeDeploymentLoaded(stored):
                if let stored {
                    state.phase = .signedIn
                    state.signedIn = SignedInFeature.State(deployment: stored)
                    state.auth = nil
                } else if state.purchaseStatus.isEntitled {
                    state.phase = .auth
                    state.auth = AuthFeature.State()
                    state.signedIn = nil
                }
                return .none

            case let .auth(.signedIn(stored)):
                let store = deploymentStore
                return .run { send in
                    try? await store.upsertActive(stored)
                    await send(.activeDeploymentLoaded(stored))
                }

            case .signedIn(.signedOut):
                let lastURL = state.signedIn?.deployment.deployment.baseURL.absoluteString ?? ""
                let lastEmail = state.signedIn?.deployment.deployment.username ?? ""
                state.phase = .auth
                state.auth = AuthFeature.State(urlInput: lastURL, emailInput: lastEmail)
                state.signedIn = nil
                return .none

            case .auth, .signedIn:
                return .none
            }
        }
        .ifLet(\.auth, action: \.auth) {
            AuthFeature()
        }
        .ifLet(\.signedIn, action: \.signedIn) {
            SignedInFeature()
        }
    }
}
