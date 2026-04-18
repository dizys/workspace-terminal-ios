#if os(iOS)
import Auth
import CoderAPI
import ComposableArchitecture
import DesignSystem
import SwiftUI
import TerminalFeature
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
                            WTAvatar(name: store.deployment.deployment.username ?? "u", size: 30)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(WTColor.background.ignoresSafeArea())
        } detail: {
            ZStack {
                WTColor.background.ignoresSafeArea()
                if let detailStore = store.scope(state: \.detail, action: \.detail) {
                    NavigationStack {
                        WorkspaceDetailView(store: detailStore) { agent in
                            store.send(.openTerminal(agent))
                        }
                        .navigationDestination(
                            item: $store.scope(state: \.terminal, action: \.terminal)
                        ) { terminalStore in
                            TerminalSessionView(store: terminalStore)
                        }
                    }
                } else {
                    WTEmptyStateView(
                        icon: "rectangle.stack.fill",
                        title: "Pick a workspace",
                        message: "Choose a workspace from the list to see details and connect to its terminal."
                    )
                }
            }
        }
        .tint(WTColor.accent)
        .sheet(
            isPresented: Binding(
                get: { store.isSettingsPresented },
                set: { _ in store.send(.settingsDismissed) }
            )
        ) {
            SettingsSheetView(store: store)
        }
    }
}

private struct SettingsSheetView: View {
    @Bindable var store: StoreOf<SignedInFeature>

    var body: some View {
        NavigationStack {
            ZStack {
                WTColor.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: WTSpace.xl) {
                        AccountCard(store: store)
                        SignOutCard(store: store)
                        Spacer(minLength: WTSpace.xl)
                    }
                    .padding(.horizontal, WTSpace.xl)
                    .padding(.top, WTSpace.lg)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { store.send(.settingsDismissed) }
                        .foregroundStyle(WTColor.accent)
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(WTColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private struct AccountCard: View {
    @Bindable var store: StoreOf<SignedInFeature>

    var body: some View {
        WTCard {
            VStack(alignment: .leading, spacing: WTSpace.lg) {
                HStack(spacing: WTSpace.md) {
                    WTAvatar(
                        name: store.deployment.deployment.username ?? "user",
                        size: 56
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.deployment.deployment.username ?? "Signed in")
                            .font(WTFont.headline)
                            .foregroundStyle(WTColor.textPrimary)
                        Text(store.deployment.deployment.baseURL.host ?? "")
                            .font(WTFont.subheadline)
                            .foregroundStyle(WTColor.textSecondary)
                    }
                    Spacer()
                }

                Divider().background(WTColor.border)

                VStack(alignment: .leading, spacing: WTSpace.sm) {
                    Text("Deployment URL")
                        .font(WTFont.captionEmphasized)
                        .foregroundStyle(WTColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(store.deployment.deployment.baseURL.absoluteString)
                        .font(WTFont.monoSmall)
                        .foregroundStyle(WTColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

private struct SignOutCard: View {
    @Bindable var store: StoreOf<SignedInFeature>
    @State private var confirming = false

    var body: some View {
        WTCard {
            VStack(spacing: WTSpace.lg) {
                VStack(alignment: .leading, spacing: WTSpace.xs) {
                    Text("Session")
                        .font(WTFont.captionEmphasized)
                        .foregroundStyle(WTColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Signing out clears the session token from this device. You'll need to sign in again.")
                        .font(WTFont.subheadline)
                        .foregroundStyle(WTColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button { confirming = true } label: {
                    HStack(spacing: WTSpace.sm) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Sign out")
                            .font(WTFont.bodyEmphasized)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(WTColor.statusError)
                    .background(
                        RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                            .fill(WTColor.statusError.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                            .strokeBorder(WTColor.statusError.opacity(0.3), lineWidth: WTStroke.hairline)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog(
            "Sign out of \(store.deployment.host)?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { store.send(.signOutTapped) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private extension StoredDeployment {
    var host: String { deployment.baseURL.host ?? deployment.displayName }
}
#endif
