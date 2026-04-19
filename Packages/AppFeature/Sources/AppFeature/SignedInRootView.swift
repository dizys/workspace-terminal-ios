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
    @AppStorage("selectedTerminalThemeID") private var selectedThemeID: String = TerminalTheme.default.id

    private var selectedTheme: TerminalTheme {
        TerminalTheme.bundled.first { $0.id == selectedThemeID } ?? .default
    }

    public init(store: StoreOf<SignedInFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            WorkspaceListView(
                store: store.scope(state: \.workspaceList, action: \.workspaceList),
                activeSessionCount: { workspace in
                    workspace.latestBuild.resources
                        .flatMap(\.agents)
                        .reduce(0) { sum, agent in
                            sum + (store.liveSessionsByAgent[agent.id] ?? 0)
                        }
                }
            )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { store.send(.settingsButtonTapped) } label: {
                            WTAvatar(name: store.deployment.deployment.username ?? "u", size: 30)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(",", modifiers: .command)
                    }
                }
        } detail: {
            ZStack {
                WTColor.background.ignoresSafeArea()
                if let detailStore = store.scope(state: \.detail, action: \.detail) {
                    NavigationStack {
                        WorkspaceDetailView(
                            store: detailStore,
                            onAgentTap: { agent in store.send(.openTerminal(agent)) },
                            liveSessions: { agentID in store.liveSessionsByAgent[agentID] ?? 0 },
                            onKillAgentSessions: { agentID in store.send(.killAgentSessions(agentID)) }
                        )
                        .navigationDestination(
                            item: $store.scope(state: \.terminals, action: \.terminals)
                        ) { terminalsStore in
                            TerminalSessionsView(store: terminalsStore)
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
        .environment(\.terminalTheme, selectedTheme)
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
                        TerminalSettingsLink()
                        AboutCard()
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

// MARK: - Terminal settings link

private struct TerminalSettingsLink: View {
    var body: some View {
        NavigationLink {
            TerminalSettingsView()
        } label: {
            WTCard {
                HStack(spacing: WTSpace.md) {
                    Image(systemName: "terminal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(WTColor.accent)
                        .frame(width: 32, height: 32)
                        .background(WTColor.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Terminal")
                            .font(WTFont.bodyEmphasized)
                            .foregroundStyle(WTColor.textPrimary)
                        Text("Theme, font size")
                            .font(WTFont.caption)
                            .foregroundStyle(WTColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WTColor.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TerminalSettingsView: View {
    @AppStorage("selectedTerminalThemeID") private var selectedThemeID: String = TerminalTheme.default.id

    var body: some View {
        ZStack {
            WTColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: WTSpace.xl) {
                    ThemePickerCard(selectedThemeID: $selectedThemeID)
                    FontSizeCard()
                    Spacer(minLength: WTSpace.xl)
                }
                .padding(.horizontal, WTSpace.xl)
                .padding(.top, WTSpace.lg)
            }
        }
        .navigationTitle("Terminal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Font size

private struct FontSizeCard: View {
    @AppStorage("terminalFontSize") private var fontSize: Double = 14
    private static let defaultSize: Double = 14

    var body: some View {
        WTCard {
            VStack(alignment: .leading, spacing: WTSpace.md) {
                HStack {
                    Text("Font Size")
                        .font(WTFont.captionEmphasized)
                        .foregroundStyle(WTColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    Text("\(Int(fontSize))pt")
                        .font(WTFont.monoSmall)
                        .foregroundStyle(WTColor.textSecondary)
                        .monospacedDigit()
                    if Int(fontSize) != Int(Self.defaultSize) {
                        Button {
                            withAnimation { fontSize = Self.defaultSize }
                        } label: {
                            Text("Reset")
                                .font(WTFont.caption)
                                .foregroundStyle(WTColor.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Slider(value: $fontSize, in: 8...32, step: 1)
                    .tint(WTColor.accent)
                HStack {
                    Text("A")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(WTColor.textTertiary)
                    Spacer()
                    Text("Default: \(Int(Self.defaultSize))pt")
                        .font(WTFont.caption)
                        .foregroundStyle(WTColor.textTertiary)
                    Spacer()
                    Text("A")
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundStyle(WTColor.textTertiary)
                }
            }
        }
    }
}

// MARK: - Theme picker

private struct ThemePickerCard: View {
    @Binding var selectedThemeID: String

    var body: some View {
        WTCard {
            VStack(alignment: .leading, spacing: WTSpace.md) {
                Text("Terminal Theme")
                    .font(WTFont.captionEmphasized)
                    .foregroundStyle(WTColor.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                VStack(spacing: WTSpace.xs) {
                    ForEach(TerminalTheme.bundled) { theme in
                        Button {
                            selectedThemeID = theme.id
                        } label: {
                            HStack(spacing: WTSpace.md) {
                                ThemePreviewDots(theme: theme)
                                Text(theme.name)
                                    .font(WTFont.bodyEmphasized)
                                    .foregroundStyle(WTColor.textPrimary)
                                Spacer()
                                if selectedThemeID == theme.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(WTColor.accent)
                                }
                            }
                            .padding(.vertical, WTSpace.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ThemePreviewDots: View {
    let theme: TerminalTheme

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(Color(uiColor: theme.background.uiColor))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(WTColor.border, lineWidth: 0.5))
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(Color(uiColor: theme.ansi[i + 1].uiColor))
                    .frame(width: 14, height: 14)
            }
        }
    }
}

// MARK: - About

private struct AboutCard: View {
    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()

    var body: some View {
        WTCard {
            VStack(spacing: WTSpace.md) {
                aboutRow(
                    icon: "hand.raised",
                    title: "Privacy Policy",
                    url: "https://workspaceterminal.app/privacy"
                )
                Divider().background(WTColor.border)
                aboutRow(
                    icon: "questionmark.circle",
                    title: "Support",
                    url: "https://github.com/dizys/workspace-terminal-ios/issues"
                )
                Divider().background(WTColor.border)
                HStack(spacing: WTSpace.md) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(WTColor.textTertiary)
                        .frame(width: 32, height: 32)
                    Text("Version")
                        .font(WTFont.bodyEmphasized)
                        .foregroundStyle(WTColor.textPrimary)
                    Spacer()
                    Text(appVersion)
                        .font(WTFont.monoSmall)
                        .foregroundStyle(WTColor.textSecondary)
                }
            }
        }
    }

    private func aboutRow(icon: String, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: WTSpace.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(WTColor.textTertiary)
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(WTFont.bodyEmphasized)
                    .foregroundStyle(WTColor.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WTColor.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

#endif
