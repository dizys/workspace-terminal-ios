import AppFeature
import ComposableArchitecture
import Testing

@Suite("App launch smoke")
struct AppLaunchTests {
    @Test("App launches into the launching stage")
    @MainActor
    func appLaunches() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.appLaunched)
    }
}
