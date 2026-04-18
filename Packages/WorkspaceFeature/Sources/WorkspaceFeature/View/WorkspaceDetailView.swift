#if os(iOS)
import CoderAPI
import ComposableArchitecture
import DesignSystem
import SwiftUI

public struct WorkspaceDetailView: View {
    @Bindable public var store: StoreOf<WorkspaceDetailFeature>
    private let onAgentTap: (WorkspaceAgent) -> Void

    public init(
        store: StoreOf<WorkspaceDetailFeature>,
        onAgentTap: @escaping (WorkspaceAgent) -> Void = { _ in }
    ) {
        self.store = store
        self.onAgentTap = onAgentTap
    }

    public var body: some View {
        ZStack {
            WTColor.background.ignoresSafeArea()
            ScrollView {
                if let workspace = store.workspace {
                    VStack(spacing: WTSpace.lg) {
                        HeroCard(workspace: workspace, pendingTransition: store.pendingTransition)
                        LifecycleCard(workspace: workspace, store: store)
                        if !store.agents.isEmpty {
                            AgentsCard(agents: store.agents, onAgentTap: onAgentTap)
                        }
                        if !store.buildLogs.isEmpty {
                            BuildLogCard(logs: store.buildLogs)
                        }
                        Spacer(minLength: WTSpace.xxxl)
                    }
                    .padding(.horizontal, WTSpace.lg)
                    .padding(.top, WTSpace.sm)
                } else if store.isLoading {
                    WTCinematicLoader(label: "Loading workspace…")
                        .frame(minHeight: 320)
                }
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
}

// MARK: - Hero

private struct HeroCard: View {
    let workspace: Workspace
    let pendingTransition: WorkspaceBuild.Transition?

    var body: some View {
        WTHeroCard {
            VStack(alignment: .leading, spacing: WTSpace.lg) {
                HStack(spacing: WTSpace.md) {
                    TemplateBigBadge(workspace: workspace)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workspace.name)
                            .font(WTFont.title)
                            .foregroundStyle(WTColor.textPrimary)
                        Text(workspace.templateDisplayName ?? workspace.templateName)
                            .font(WTFont.subheadline)
                            .foregroundStyle(WTColor.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: WTSpace.sm) {
                    WTStatusPill(label: statusLabel, tone: statusTone)
                    if let lastUsed = workspace.lastUsedAt {
                        Text("· \(relative(lastUsed))")
                            .font(WTFont.caption)
                            .foregroundStyle(WTColor.textTertiary)
                    }
                    Spacer()
                }
            }
        }
    }

    private var statusLabel: String {
        if let pendingTransition {
            switch pendingTransition {
            case .start:  return "Starting…"
            case .stop:   return "Stopping…"
            case .delete: return "Deleting…"
            }
        }
        return workspace.latestBuild.status.rawValue.capitalized
    }

    private var statusTone: WTStatusPill.Tone {
        if pendingTransition != nil { return .pending }
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
        formatter.unitsStyle = .full
        return "Last used " + formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct TemplateBigBadge: View {
    let workspace: Workspace
    var body: some View {
        let initial = String((workspace.templateDisplayName ?? workspace.templateName).prefix(1)).uppercased()
        ZStack {
            RoundedRectangle(cornerRadius: WTRadius.lg, style: .continuous)
                .fill(WTColor.accentSoft)
                .frame(width: 56, height: 56)
            Text(initial)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(WTColor.accent)
        }
    }
}

// MARK: - Lifecycle

private struct LifecycleCard: View {
    let workspace: Workspace
    let store: StoreOf<WorkspaceDetailFeature>

    var body: some View {
        WTCard {
            VStack(alignment: .leading, spacing: WTSpace.md) {
                Text("Lifecycle")
                    .font(WTFont.captionEmphasized)
                    .foregroundStyle(WTColor.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(spacing: WTSpace.sm) {
                    LifecycleButton(
                        title: "Start",
                        icon: "play.fill",
                        tone: .accent,
                        enabled: workspace.canStart && store.pendingTransition == nil
                    ) { store.send(.startTapped) }

                    LifecycleButton(
                        title: "Stop",
                        icon: "stop.fill",
                        tone: .destructive,
                        enabled: workspace.canStop && store.pendingTransition == nil
                    ) { store.send(.stopTapped) }

                    LifecycleButton(
                        title: "Restart",
                        icon: "arrow.clockwise",
                        tone: .neutral,
                        enabled: workspace.canRestart && store.pendingTransition == nil
                    ) { store.send(.restartTapped) }
                }
            }
        }
    }
}

private struct LifecycleButton: View {
    enum Tone { case accent, destructive, neutral }
    let title: String
    let icon: String
    let tone: Tone
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: WTSpace.xs + 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(WTFont.captionEmphasized)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .strokeBorder(border, lineWidth: WTStroke.hairline)
            )
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var foreground: Color {
        switch tone {
        case .accent:      return WTColor.accent
        case .destructive: return WTColor.statusError
        case .neutral:     return WTColor.textPrimary
        }
    }
    private var background: Color {
        switch tone {
        case .accent:      return WTColor.accentSoft
        case .destructive: return WTColor.statusError.opacity(0.12)
        case .neutral:     return WTColor.surface
        }
    }
    private var border: Color {
        switch tone {
        case .accent:      return WTColor.accent.opacity(0.35)
        case .destructive: return WTColor.statusError.opacity(0.3)
        case .neutral:     return WTColor.border
        }
    }
}

// MARK: - Agents

private struct AgentsCard: View {
    let agents: [WorkspaceAgent]
    let onAgentTap: (WorkspaceAgent) -> Void

    var body: some View {
        WTCard {
            VStack(alignment: .leading, spacing: WTSpace.md) {
                Text("Agents")
                    .font(WTFont.captionEmphasized)
                    .foregroundStyle(WTColor.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                VStack(spacing: WTSpace.sm) {
                    ForEach(agents) { agent in
                        Button { onAgentTap(agent) } label: {
                            HStack(spacing: WTSpace.md) {
                                WTStatusDot(tone: tone(for: agent.status))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(agent.name)
                                        .font(WTFont.bodyEmphasized)
                                        .foregroundStyle(WTColor.textPrimary)
                                    Text("\(agent.operatingSystem ?? "?") · \(agent.architecture ?? "?")")
                                        .font(WTFont.caption)
                                        .foregroundStyle(WTColor.textSecondary)
                                }
                                Spacer()
                                if agent.isDevcontainer {
                                    Text("devcontainer")
                                        .font(WTFont.caption)
                                        .foregroundStyle(WTColor.accent)
                                        .padding(.horizontal, WTSpace.sm)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(WTColor.accentSoft)
                                        )
                                }
                                Image(systemName: "terminal")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(WTColor.accent)
                            }
                            .padding(.vertical, WTSpace.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(agent.status != .connected)
                        .opacity(agent.status == .connected ? 1 : 0.5)
                    }
                }
            }
        }
    }

    private func tone(for status: WorkspaceAgent.Status) -> WTStatusPill.Tone {
        switch status {
        case .connected:                return .running
        case .connecting:               return .pending
        case .disconnected, .timeout:   return .error
        case .unknown:                  return .neutral
        }
    }
}

// MARK: - Build log

private struct BuildLogCard: View {
    let logs: [BuildLog]

    var body: some View {
        WTCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Build log")
                        .font(WTFont.captionEmphasized)
                        .foregroundStyle(WTColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    WTStatusDot(tone: .pending)
                }
                .padding(WTSpace.lg)

                Divider().background(WTColor.border)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logs) { log in
                            HStack(alignment: .top, spacing: WTSpace.sm) {
                                Text(stage(log.stage))
                                    .font(WTFont.monoSmall)
                                    .foregroundStyle(WTColor.textTertiary)
                                    .frame(width: 80, alignment: .leading)
                                Text(log.output)
                                    .font(WTFont.monoSmall)
                                    .foregroundStyle(color(for: log.logLevel))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(WTSpace.lg)
                }
                .frame(maxHeight: 280)
                .background(WTColor.background.opacity(0.5))
            }
        }
    }

    private func stage(_ s: String) -> String {
        s.isEmpty ? "·" : s
    }

    private func color(for level: BuildLog.Level) -> Color {
        switch level {
        case .error: return WTColor.statusError
        case .warn:  return WTColor.statusWarning
        case .info:  return WTColor.textPrimary
        case .debug, .trace: return WTColor.textSecondary
        case .unknown: return WTColor.textPrimary
        }
    }
}
#endif
