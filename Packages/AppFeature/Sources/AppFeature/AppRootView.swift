#if os(iOS)
import ComposableArchitecture
import DesignSystem
import SwiftUI

public struct AppRootView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.stage {
            case .launching:
                LaunchView()
            case .paywall:
                PaywallStubView(store: store)
            case .loggedOut:
                LoginStubView(store: store)
            case .loggedIn:
                WorkspaceListStubView(store: store)
            }
        }
        .task {
            store.send(.appLaunched)
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal")
                .font(.system(size: 64))
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct PaywallStubView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
            Text("Workspace Terminal")
                .font(.largeTitle).bold()
            Text("Paywall stub — replace in M0 with StoreKit 2 product page.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Pretend to purchase") {
                store.send(.purchaseStatusLoaded(.purchased(transactionID: 1)))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct LoginStubView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
            Text("Sign in")
                .font(.largeTitle).bold()
            Text("Login stub — OIDC + GitHub + password arrive in M1.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Pretend to log in") {
                store.send(.loginCompleted)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct WorkspaceListStubView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No workspaces yet",
                systemImage: "rectangle.stack.badge.plus",
                description: Text("Workspace list arrives in M1.")
            )
            .navigationTitle("Workspaces")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") { store.send(.loggedOut) }
                }
            }
        }
    }
}
#endif
