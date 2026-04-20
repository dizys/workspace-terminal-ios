import CoderAPI
import ComposableArchitecture
import Foundation
import PTYTransport
import Testing
@testable import TerminalFeature

@Suite("TerminalFeature reducer", .serialized)
@MainActor
struct TerminalFeatureReducerTests {
    private func makeAgent() -> WorkspaceAgent {
        WorkspaceAgent(
            id: UUID(),
            name: "main",
            status: .connected,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeDeployment() -> Deployment {
        Deployment(baseURL: URL(string: "https://coder.example.com")!, displayName: "test")
    }

    @Test("initial state is .idle")
    func initialState() async {
        let store = TestStore(
            initialState: TerminalFeature.State(
                agent: makeAgent(),
                deployment: makeDeployment()
            )
        ) {
            TerminalFeature()
        }
        store.assert {
            $0.connection = .idle
            $0.totalBytesReceived = 0
            $0.lastError = nil
        }
    }

    @Test("stateChanged updates connection phase")
    func stateChangedUpdatesPhase() async {
        let store = TestStore(
            initialState: TerminalFeature.State(
                agent: makeAgent(),
                deployment: makeDeployment()
            )
        ) {
            TerminalFeature()
        }
        await store.send(.stateChanged(.connecting(attempt: 1))) {
            $0.connection = .connecting(attempt: 1)
        }
        await store.send(.stateChanged(.connected)) {
            $0.connection = .connected
        }
        await store.send(.stateChanged(.reconnecting(attempt: 2, lastError: nil))) {
            $0.connection = .reconnecting(attempt: 2)
        }
        await store.send(.stateChanged(.closed(.userInitiated))) {
            $0.connection = .closed(reasonDescription: "Terminal closed.")
        }
    }

    @Test("bytesReceived updates byte counter (no large payload in state)")
    func bytesReceivedAccumulates() async {
        let store = TestStore(
            initialState: TerminalFeature.State(
                agent: makeAgent(),
                deployment: makeDeployment()
            )
        ) {
            TerminalFeature()
        }
        await store.send(.bytesReceived(count: 5)) {
            $0.totalBytesReceived = 5
        }
        await store.send(.bytesReceived(count: 12)) {
            $0.totalBytesReceived = 17
        }
    }

    @Test("errorRaised stores message; dismissError clears it")
    func errorRaisedAndDismiss() async {
        let store = TestStore(
            initialState: TerminalFeature.State(
                agent: makeAgent(),
                deployment: makeDeployment()
            )
        ) {
            TerminalFeature()
        }
        await store.send(.errorRaised("boom")) {
            $0.lastError = "boom"
        }
        await store.send(.dismissError) {
            $0.lastError = nil
        }
    }

    @Test("resize updates state.size (UI-driven)")
    func resizeUpdatesSize() async {
        let store = TestStore(
            initialState: TerminalFeature.State(
                agent: makeAgent(),
                deployment: makeDeployment()
            )
        ) {
            TerminalFeature()
        }
        await store.send(.resize(TerminalSize(rows: 40, cols: 120))) {
            $0.size = TerminalSize(rows: 40, cols: 120)
        }
    }
}
