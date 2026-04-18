#if os(iOS)
import Auth
import CoderAPI
import ComposableArchitecture
import SwiftUI
import WorkspaceFeature

public struct SignedInRootView: View {
    @Bindable var store: StoreOf<SignedInFeature>

    public init(store: StoreOf<SignedInFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            WorkspaceListView(store: store.scope(state: \.workspaceList, action: \.workspaceList))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { store.send(.settingsButtonTapped) } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        } detail: {
            if let detailStore = store.scope(state: \.detail, action: \.detail) {
                NavigationStack {
                    WorkspaceDetailView(store: detailStore)
                }
            } else {
                ContentUnavailableView(
                    "Pick a workspace",
                    systemImage: "rectangle.stack",
                    description: Text("Choose a workspace from the list to see details.")
                )
            }
        }
        .sheet(
            isPresented: Binding(get: { store.isSettingsPresented }, set: { _ in store.send(.settingsDismissed) })
        ) {
            SettingsView(store: store)
        }
    }
}

struct SettingsView: View {
    @Bindable var store: StoreOf<SignedInFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("URL", value: store.deployment.deployment.baseURL.absoluteString)
                    LabeledContent("User", value: store.deployment.deployment.username ?? "—")
                }

                Section {
                    Button(role: .destructive) { store.send(.signOutTapped) } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Session")
                } footer: {
                    Text("Signing out clears the session token from this device. You'll need to sign in again to access this deployment.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { store.send(.settingsDismissed) }
                }
            }
        }
    }
}
#endif
