import AppFeature
import ComposableArchitecture
import SwiftUI

@main
struct WorkspaceTerminalApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
        }
    }
}
