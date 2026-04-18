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
        Group {
            if store.workspaces.isEmpty, store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.workspaces.isEmpty {
                ContentUnavailableView(
                    "No workspaces",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("This account has no workspaces yet. Create one in the Coder dashboard.")
                )
            } else {
                List {
                    ForEach(store.workspaces) { workspace in
                        Button { store.send(.workspaceTapped(workspace.id)) } label: {
                            WorkspaceRow(workspace: workspace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Workspaces")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.send(.refresh) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .refreshable { store.send(.refresh) }
        .task { store.send(.onAppear) }
        .alert("Couldn't load workspaces",
               isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.send(.dismissError) } })) {
            Button("OK", role: .cancel) { store.send(.dismissError) }
        } message: {
            Text(store.error ?? "")
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(status: workspace.latestBuild.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name).font(.headline)
                Text(workspace.templateDisplayName ?? workspace.templateName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: WorkspaceBuild.Status

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 4))
    }

    private var color: Color {
        switch status {
        case .running:                  return .green
        case .starting, .pending:       return .blue
        case .stopped:                  return .gray
        case .stopping, .deleting,
             .canceling:                return .orange
        case .failed:                   return .red
        case .deleted, .canceled:       return .secondary
        }
    }
}
#endif
