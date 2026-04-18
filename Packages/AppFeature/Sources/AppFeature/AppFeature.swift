import ComposableArchitecture
import Foundation
import StoreKitClient

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var purchaseStatus: PurchaseStatus
        public var stage: Stage

        public init(purchaseStatus: PurchaseStatus = .unknown, stage: Stage = .launching) {
            self.purchaseStatus = purchaseStatus
            self.stage = stage
        }
    }

    public enum Stage: Sendable, Equatable {
        case launching
        case paywall
        case loggedOut
        case loggedIn
    }

    public enum Action: Equatable {
        case appLaunched
        case purchaseStatusLoaded(PurchaseStatus)
        case loginCompleted
        case loggedOut
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appLaunched:
                state.stage = .launching
                return .none
            case let .purchaseStatusLoaded(status):
                state.purchaseStatus = status
                state.stage = status.isEntitled ? .loggedOut : .paywall
                return .none
            case .loginCompleted:
                state.stage = .loggedIn
                return .none
            case .loggedOut:
                state.stage = .loggedOut
                return .none
            }
        }
    }
}
