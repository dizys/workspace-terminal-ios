#if os(iOS)
import ComposableArchitecture
import DesignSystem
import SwiftUI

/// Multi-tab container hosting one `TerminalSessionView` per tab.
///
/// UX:
/// - Single tab: full-screen terminal, no chrome.
/// - Multiple tabs: swipe horizontally to switch; the toolbar shows a
///   compact `1/3 ▾` counter that opens a popover with the tab list,
///   close affordances, and a "+ New tab" row.
/// - Cmd+T (hardware keyboard) adds a new tab from any state.
public struct TerminalSessionsView: View {
    @Bindable var store: StoreOf<TerminalSessionsFeature>
    @Environment(\.dismiss) private var dismiss
    @State private var showingTabsPopover: Bool = false

    public init(store: StoreOf<TerminalSessionsFeature>) {
        self.store = store
    }

    public var body: some View {
        terminalPager
            .background(WTColor.background.ignoresSafeArea())
            .background(hiddenShortcuts)
            .navigationTitle(store.agent.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { tabsControl }
            .task { store.send(.onAppear) }
    }

    // MARK: - Toolbar

    // Two separate ToolbarItems instead of one with if/else. SwiftUI's toolbar
    // layout engine reserves space for the widest variant of a conditional view
    // inside a single ToolbarItem, causing the "extra blank" expansion bug.
    @ToolbarContentBuilder
    private var tabsControl: some ToolbarContent {
        if store.tabs.count <= 1 {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.send(.addTabTapped) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WTColor.accent)
                }
                .buttonStyle(.plain)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingTabsPopover = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(currentTabIndex + 1)/\(store.tabs.count)")
                            .font(WTFont.captionEmphasized)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                    .foregroundStyle(WTColor.accent)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingTabsPopover, arrowEdge: .top) {
                    TabsPopover(
                        store: store,
                        onDismiss: { showingTabsPopover = false }
                    )
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                    .frame(idealHeight: 320, maxHeight: 480)
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
    }

    /// Hidden buttons attached as a background — they bind keyboard shortcuts
    /// without participating in toolbar layout, which avoids Mac Catalyst
    /// rendering the shortcut hint inline (which expands the toolbar item).
    private var hiddenShortcuts: some View {
        ZStack {
            Button("New Tab") { store.send(.addTabTapped) }
                .keyboardShortcut("t", modifiers: .command)
            Button("Close Tab") {
                if let id = store.selectedID {
                    store.send(.closeTabTapped(id))
                }
            }
            .keyboardShortcut("w", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Pager

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
        // No bottom dot indicator — it overlapped TUI bottom bars (nano, etc).
        // Tab discovery + selection lives in the toolbar popover instead.
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var currentTabIndex: Int {
        guard let id = store.selectedID,
              let idx = store.tabs.index(id: id) else { return 0 }
        return idx
    }
}

// MARK: - Tabs popover

private struct TabsPopover: View {
    @Bindable var store: StoreOf<TerminalSessionsFeature>
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabList
            Divider()
            newTabRow
        }
    }

    private var header: some View {
        HStack {
            Text("Tabs")
                .font(WTFont.captionEmphasized)
                .foregroundStyle(WTColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            Text("\(store.tabs.count)")
                .font(WTFont.captionEmphasized)
                .foregroundStyle(WTColor.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, WTSpace.lg)
        .padding(.vertical, WTSpace.md)
    }

    private var tabList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.tabs.enumerated()), id: \.element.sessionID) { index, tab in
                    Button {
                        store.send(.selectTab(tab.sessionID))
                        onDismiss()
                    } label: {
                        HStack(spacing: WTSpace.sm) {
                            Image(systemName: "terminal")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(store.selectedID == tab.sessionID
                                                 ? WTColor.accent
                                                 : WTColor.textSecondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(tab.agent.name) \(index + 1)")
                                    .font(WTFont.bodyEmphasized)
                                    .foregroundStyle(WTColor.textPrimary)
                                Text(connectionLabel(tab.connection))
                                    .font(WTFont.caption)
                                    .foregroundStyle(WTColor.textTertiary)
                            }
                            Spacer()
                            if store.selectedID == tab.sessionID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(WTColor.accent)
                            }
                            Button {
                                // Dismiss FIRST so the popover closes cleanly
                                // before the tabs array mutates underneath it.
                                // The closeTabTapped action fires after dismiss
                                // completes, preventing the popover from
                                // re-anchoring mid-close.
                                let tabID = tab.sessionID
                                onDismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    store.send(.closeTabTapped(tabID))
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(WTColor.textTertiary)
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, WTSpace.lg)
                        .padding(.vertical, WTSpace.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < store.tabs.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
    }

    private var newTabRow: some View {
        Button {
            store.send(.addTabTapped)
            onDismiss()
        } label: {
            HStack(spacing: WTSpace.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WTColor.accent)
                    .frame(width: 24)
                Text("New tab")
                    .font(WTFont.bodyEmphasized)
                    .foregroundStyle(WTColor.accent)
                Spacer()
            }
            .padding(.horizontal, WTSpace.lg)
            .padding(.vertical, WTSpace.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func connectionLabel(_ phase: TerminalFeature.State.Phase) -> String {
        switch phase {
        case .idle:                            return "idle"
        case let .connecting(attempt):         return attempt > 1 ? "connecting (try \(attempt))…" : "connecting…"
        case .connected:                       return "connected"
        case let .reconnecting(attempt):       return "reconnecting (try \(attempt))…"
        case .closed:                          return "closed"
        }
    }
}
#endif
