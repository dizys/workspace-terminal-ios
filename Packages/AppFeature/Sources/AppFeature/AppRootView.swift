#if os(iOS)
import Auth
import CoderAPI
import ComposableArchitecture
import DesignSystem
import SwiftUI
import WorkspaceFeature

public struct AppRootView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.phase {
            case .launching:
                LaunchView()
            case .paywall:
                PaywallStubView()
            case .auth:
                if let authStore = store.scope(state: \.auth, action: \.auth) {
                    NavigationStack { LoginView(store: authStore) }
                }
            case .signedIn:
                if let signedInStore = store.scope(state: \.signedIn, action: \.signedIn) {
                    SignedInRootView(store: signedInStore)
                }
            }
        }
        .task { store.send(.appLaunched) }
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
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
            Text("Workspace Terminal")
                .font(.largeTitle).bold()
            Text("Paywall stub — replaced in M0 with StoreKit 2 product page.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
#endif
