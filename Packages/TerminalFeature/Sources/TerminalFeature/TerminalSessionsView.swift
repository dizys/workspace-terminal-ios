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
        terminalPager
            .background(WTColor.background.ignoresSafeArea())
        .navigationTitle(store.tabs.count > 1
                         ? "\(store.agent.name) (\(currentTabIndex + 1)/\(store.tabs.count))"
                         : store.agent.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.send(.addTabTapped) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WTColor.accent)
                }
            }
            // Hidden Cmd+T binding — keeping it on the visible button caused
            // Mac Catalyst to render the shortcut hint inline, expanding the
            // toolbar item width unpredictably.
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Tab") { store.send(.addTabTapped) }
                    .keyboardShortcut("t", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .task { store.send(.onAppear) }
    }

    private var currentTabIndex: Int {
        guard let id = store.selectedID,
              let idx = store.tabs.index(id: id) else { return 0 }
        return idx
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
        // Show small page-dot indicator only when 2+ tabs; hidden for single
        // tab so the terminal gets the full screen.
        .tabViewStyle(.page(indexDisplayMode: store.tabs.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: store.tabs.count > 1 ? .always : .never))
    }

}
#endif
