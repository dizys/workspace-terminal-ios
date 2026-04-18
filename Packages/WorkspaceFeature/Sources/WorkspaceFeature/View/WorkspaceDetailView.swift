#if os(iOS)
import CoderAPI
import ComposableArchitecture
import DesignSystem
import SwiftUI

public struct WorkspaceDetailView: View {
    @Bindable public var store: StoreOf<WorkspaceDetailFeature>

    public init(store: StoreOf<WorkspaceDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            if let workspace = store.workspace {
                Section("Overview") {
                    LabeledContent("Status") { StatusPill(status: workspace.latestBuild.status) }
                    LabeledContent("Template", value: workspace.templateDisplayName ?? workspace.templateName)
                    LabeledContent("Owner", value: workspace.ownerName)
                    if let lastUsed = workspace.lastUsedAt {
                        LabeledContent("Last used", value: lastUsed, format: .relative(presentation: .named))
                    }
                }

                Section("Lifecycle") {
                    Button("Start", systemImage: "play.fill") { store.send(.startTapped) }
                        .disabled(!workspace.canStart || store.pendingTransition != nil)
                    Button("Stop", systemImage: "stop.fill") { store.send(.stopTapped) }
                        .disabled(!workspace.canStop || store.pendingTransition != nil)
                    Button("Restart", systemImage: "arrow.clockwise") { store.send(.restartTapped) }
                        .disabled(!workspace.canRestart || store.pendingTransition != nil)
                }

                if !store.agents.isEmpty {
                    Section("Agents") {
                        ForEach(store.agents) { agent in
                            HStack {
                                AgentStatusDot(status: agent.status)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(agent.name).font(.body)
                                    Text("\(agent.operatingSystem ?? "?") · \(agent.architecture ?? "?")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if agent.isDevcontainer {
                                    Text("devcontainer").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !store.buildLogs.isEmpty {
                    Section("Build log") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(store.buildLogs) { log in
                                    Text(log.output)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(color(for: log.logLevel))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxHeight: 240)
                    }
                }
            } else if store.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(store.workspace?.name ?? "Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { store.send(.refresh) }
        .task { store.send(.onAppear) }
        .alert("Something went wrong",
               isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.send(.dismissError) } })) {
            Button("OK", role: .cancel) { store.send(.dismissError) }
        } message: {
            Text(store.error ?? "")
        }
    }

    private func color(for level: BuildLog.Level) -> Color {
        switch level {
        case .error: return .red
        case .warn:  return .orange
        case .info, .debug, .trace, .unknown: return .primary
        }
    }
}

struct StatusPill: View {
    let status: WorkspaceBuild.Status
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
    private var color: Color {
        switch status {
        case .running: return .green
        case .starting, .pending: return .blue
        case .stopped: return .gray
        case .stopping, .deleting, .canceling: return .orange
        case .failed: return .red
        case .deleted, .canceled: return .secondary
        }
    }
}

struct AgentStatusDot: View {
    let status: WorkspaceAgent.Status
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }
    private var color: Color {
        switch status {
        case .connected: return .green
        case .connecting: return .blue
        case .disconnected, .timeout: return .red
        case .unknown: return .gray
        }
    }
}
#endif
