import ComposableArchitecture
import PTYTransport
import Testing
@testable import TerminalFeature

@Suite("TerminalFeature smoke")
struct TerminalFeatureTests {
    @Test("onAppear transitions to connecting")
    @MainActor
    func onAppearConnecting() async {
        let store = TestStore(initialState: TerminalFeature.State()) {
            TerminalFeature()
        }
        await store.send(.onAppear) {
            $0.connection = .connecting
        }
    }

    @Test("resize updates size")
    @MainActor
    func resizeUpdates() async {
        let store = TestStore(initialState: TerminalFeature.State()) {
            TerminalFeature()
        }
        let newSize = TerminalSize(rows: 50, cols: 200)
        await store.send(.resize(newSize)) {
            $0.size = newSize
        }
    }
}
