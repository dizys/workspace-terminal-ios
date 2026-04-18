#if os(iOS)
import ComposableArchitecture
import DesignSystem
import SwiftUI

/// Multi-tab container hosting one `TerminalSessionView` per tab.
/// Swipe horizontally to switch tabs (TabView page style); tap a pill in the
/// strip to jump directly; "+" adds a new tab on the same agent; "×" closes.
public struct TerminalSessionsView: View {
    @Bindable var store: StoreOf<TerminalSessionsFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<TerminalSessionsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider().background(WTColor.border)
            terminalPager
        }
        .background(WTColor.background.ignoresSafeArea())
        .navigationTitle(store.agent.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.send(.addTabTapped) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WTColor.accent)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
        .task { store.send(.onAppear) }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WTSpace.xs) {
                ForEach(store.tabs) { tab in
                    TabPill(
                        title: tabTitle(tab),
                        isSelected: store.selectedID == tab.sessionID,
                        canClose: store.tabs.count > 1,
                        onTap: { store.send(.selectTab(tab.sessionID)) },
                        onClose: { store.send(.closeTabTapped(tab.sessionID)) }
                    )
                }
            }
            .padding(.horizontal, WTSpace.md)
            .padding(.vertical, WTSpace.xs)
        }
        .background(WTColor.surface)
    }

    private var terminalPager: some View {
        TabView(selection: $store.selectedID.sending(\.selectTab)) {
            ForEach(
                store.scope(state: \.tabs, action: \.tabs)
            ) { tabStore in
                TerminalSessionView(
                    store: tabStore,
                    isActive: store.selectedID == tabStore.sessionID
                )
                .tag(Optional(tabStore.sessionID))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func tabTitle(_ tab: TerminalFeature.State) -> String {
        // Number tabs by their position so they stay distinguishable.
        if let index = store.tabs.index(id: tab.sessionID) {
            return "\(tab.agent.name) \(index + 1)"
        }
        return tab.agent.name
    }
}

private struct TabPill: View {
    let title: String
    let isSelected: Bool
    let canClose: Bool
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onTap) {
                Text(title)
                    .font(WTFont.captionEmphasized)
                    .foregroundStyle(isSelected ? WTColor.background : WTColor.textPrimary)
            }
            .buttonStyle(.plain)
            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? WTColor.background.opacity(0.7) : WTColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, WTSpace.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? WTColor.accent : WTColor.surfaceElevated)
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.clear : WTColor.border, lineWidth: 0.5)
        )
    }
}
#endif
