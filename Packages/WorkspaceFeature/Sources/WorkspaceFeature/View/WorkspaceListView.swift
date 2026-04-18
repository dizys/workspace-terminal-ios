#if os(iOS)
import CoderAPI
import ComposableArchitecture
import DesignSystem
import SwiftUI

public struct WorkspaceListView: View {
    @Bindable public var store: StoreOf<WorkspaceListFeature>

    public init(store: StoreOf<WorkspaceListFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .background(WTColor.background)
            .navigationTitle("Workspaces")
            .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.send(.refresh) } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WTColor.accent)
                }
                .disabled(store.isLoading)
            }
        }
        .refreshable { store.send(.refresh) }
        .task { store.send(.onAppear) }
        .alert("Couldn't load workspaces",
               isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.send(.dismissError) } })) {
            Button("Retry") { store.send(.refresh) }
            Button("OK", role: .cancel) { store.send(.dismissError) }
        } message: {
            Text(store.error ?? "")
        }
    }

    // List(selection:) is the canonical native pattern: NavigationSplitView
    // routes the selection automatically — pushes on iPhone-compact, shows
    // in the detail column on iPad-regular. We bridge selection back into TCA
    // via .onChange so the parent feature can update the detail state.
    @ViewBuilder
    private var content: some View {
        List(selection: $store.selectedID.sending(\.selectionChanged)) {
            if store.workspaces.isEmpty, store.isLoading {
                WTCinematicLoader(label: "Loading workspaces…")
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            } else if store.workspaces.isEmpty {
                WTEmptyStateView(
                    icon: "rectangle.stack.badge.plus",
                    title: "No workspaces yet",
                    message: "Create one in your Coder dashboard, then pull to refresh.",
                    actionTitle: "Refresh",
                    action: { store.send(.refresh) }
                )
                .frame(maxWidth: .infinity)
                .padding(.top, WTSpace.xxl)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            } else {
                ForEach(store.workspaces) { workspace in
                    WorkspaceCard(workspace: workspace)
                        .tag(workspace.id)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: WTSpace.xs, leading: WTSpace.lg,
                                                  bottom: WTSpace.xs, trailing: WTSpace.lg))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Card

struct WorkspaceCard: View {
    let workspace: Workspace

    var body: some View {
        WTCard {
            HStack(alignment: .top, spacing: WTSpace.md) {
                TemplateBadge(workspace: workspace)
                VStack(alignment: .leading, spacing: WTSpace.xs) {
                    HStack(spacing: WTSpace.sm) {
                        Text(workspace.name)
                            .font(WTFont.headline)
                            .foregroundStyle(WTColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: WTSpace.sm)
                        WTStatusPill(label: statusLabel, tone: statusTone)
                    }

                    Text(workspace.templateDisplayName ?? workspace.templateName)
                        .font(WTFont.subheadline)
                        .foregroundStyle(WTColor.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: WTSpace.md) {
                        IconLabel(icon: "person.fill", text: workspace.ownerName)
                        if let lastUsed = workspace.lastUsedAt {
                            IconLabel(
                                icon: "clock.fill",
                                text: relative(lastUsed)
                            )
                        }
                        if workspace.outdated {
                            IconLabel(
                                icon: "arrow.up.circle.fill",
                                text: "Outdated",
                                color: WTColor.statusWarning
                            )
                        }
                    }
                    .padding(.top, WTSpace.xs)
                }
            }
        }
    }

    private var statusLabel: String {
        workspace.latestBuild.status.rawValue.capitalized
    }

    private var statusTone: WTStatusPill.Tone {
        switch workspace.latestBuild.status {
        case .running:                          return .running
        case .starting, .pending:               return .pending
        case .stopped:                          return .stopped
        case .stopping, .deleting, .canceling:  return .pending
        case .failed:                           return .error
        case .deleted, .canceled:               return .neutral
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct TemplateBadge: View {
    let workspace: Workspace

    var body: some View {
        let initial = String((workspace.templateDisplayName ?? workspace.templateName).prefix(1)).uppercased()
        ZStack {
            RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                .fill(WTColor.accentSoft)
                .frame(width: 44, height: 44)
            RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                .strokeBorder(WTColor.accent.opacity(0.4), lineWidth: WTStroke.hairline)
                .frame(width: 44, height: 44)
            Text(initial)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(WTColor.accent)
        }
    }
}

private struct IconLabel: View {
    let icon: String
    let text: String
    var color: Color = WTColor.textTertiary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(WTFont.caption)
        }
        .foregroundStyle(color)
        .lineLimit(1)
    }
}

private struct WorkspaceCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(WTMotion.snap, value: configuration.isPressed)
    }
}
#endif
