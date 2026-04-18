#if os(iOS)
import ComposableArchitecture
import DesignSystem
import PTYTransport
import SwiftUI
import TerminalUI

/// Top-level view for one terminal tab: hosts the SwiftTerm wrapper and a
/// status overlay reflecting connection phase.
public struct TerminalSessionView: View {
    @Bindable var store: StoreOf<TerminalFeature>
    @Dependency(\.terminalSessionStore) private var sessionStore

    public init(store: StoreOf<TerminalFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            WTColor.background.ignoresSafeArea()
            WTTerminalView(
                inbound: { inboundStream() },
                onSend: { bytes in send(bytes: bytes) },
                onResize: { rows, cols in
                    store.send(.resize(TerminalSize(rows: rows, cols: cols)))
                },
                onError: { msg in store.send(.errorRaised(msg)) }
            )
            // Do NOT ignoreSafeArea(.bottom) — that pushes the terminal under
            // the SwiftTerm input accessory bar + system keyboard, hiding the
            // last lines. Respecting the bottom safe area lets SwiftTerm's
            // UIScrollView shrink to the visible region.

            StatusOverlay(phase: store.connection)
                .padding(WTSpace.md)
        }
        .navigationTitle(store.agent.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .alert("Terminal error",
               isPresented: Binding(get: { store.lastError != nil },
                                    set: { if !$0 { store.send(.dismissError) } })) {
            Button("OK", role: .cancel) { store.send(.dismissError) }
        } message: {
            Text(store.lastError ?? "")
        }
    }

    private func inboundStream() -> AsyncThrowingStream<Data, Error> {
        // Bridge: cold → live, with a short polling window for the session
        // to be attached. The reducer's .onAppear effect creates the transport
        // and registers the session asynchronously, so the very first
        // inboundStream() call from WTTerminalView typically sees nil. We
        // poll for up to ~5s before giving up.
        let id = store.sessionID
        let store = sessionStore
        return AsyncThrowingStream { continuation in
            let task = Task {
                var session: TerminalSession?
                for _ in 0..<50 { // ≈5s at 100ms cadence
                    if Task.isCancelled { return }
                    if let s = await store.session(for: id) {
                        session = s
                        break
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                guard let session else {
                    continuation.finish()
                    return
                }
                do {
                    for try await chunk in session.inbound {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func send(bytes: Data) {
        let id = store.sessionID
        Task {
            if let session = await sessionStore.session(for: id) {
                try? await session.send(bytes)
            }
        }
        store.send(.userInputSent)
    }
}

private struct StatusOverlay: View {
    let phase: TerminalFeature.State.Phase

    var body: some View {
        HStack {
            Spacer()
            VStack {
                pill
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var pill: some View {
        switch phase {
        case .idle:
            EmptyView()
        case let .connecting(attempt):
            badge("Connecting (try \(attempt))…", tone: .warning)
        case .connected:
            EmptyView() // no chrome when healthy
        case let .reconnecting(attempt):
            badge("Reconnecting (try \(attempt))…", tone: .warning)
        case let .closed(reason):
            badge("Closed: \(reason)", tone: .error)
        }
    }

    private func badge(_ text: String, tone: Tone) -> some View {
        Text(text)
            .font(WTFont.captionEmphasized)
            .padding(.horizontal, WTSpace.md)
            .padding(.vertical, WTSpace.xs)
            .background(
                Capsule()
                    .fill(tone == .error ? WTColor.statusError.opacity(0.2) : WTColor.statusWarning.opacity(0.2))
            )
            .overlay(
                Capsule().stroke(tone == .error ? WTColor.statusError : WTColor.statusWarning, lineWidth: 1)
            )
            .foregroundStyle(tone == .error ? WTColor.statusError : WTColor.statusWarning)
    }

    private enum Tone { case warning, error }
}
#endif
