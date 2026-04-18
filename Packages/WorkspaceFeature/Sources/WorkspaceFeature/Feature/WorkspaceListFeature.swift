import CoderAPI
import ComposableArchitecture
import Foundation

/// The user's list of workspaces, with pull-to-refresh + status polling.
@Reducer
public struct WorkspaceListFeature {
    @ObservableState
    public struct State: Equatable {
        public var workspaces: [Workspace] = []
        public var isLoading: Bool = false
        public var error: String?
        public var lastFetchedAt: Date?
        /// Bound to `List(selection:)` so NavigationSplitView can route the
        /// tap natively (push on iPhone-compact, detail-column on iPad-regular).
        public var selectedID: Workspace.ID?

        public init(workspaces: [Workspace] = []) {
            self.workspaces = workspaces
        }
    }

    public enum Action: Equatable {
        case onAppear
        case refresh
        case loaded(Result<[Workspace], WorkspaceFailure>)
        case dismissError
        case workspaceTapped(Workspace.ID)
        case selectionChanged(Workspace.ID?)
    }

    @Dependency(\.authenticatedAPIClient) var apiClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear, .refresh:
                state.isLoading = true
                let client = apiClient
                return .run { send in
                    guard let api = await client() else {
                        await send(.loaded(.failure(WorkspaceFailure(message: "Not signed in"))))
                        return
                    }
                    do {
                        let workspaces = try await api.listMyWorkspaces()
                        await send(.loaded(.success(workspaces)))
                    } catch {
                        await send(.loaded(.failure(WorkspaceFailure(error))))
                    }
                }

            case let .loaded(.success(workspaces)):
                state.workspaces = workspaces.sorted(by: { $0.name < $1.name })
                state.isLoading = false
                state.lastFetchedAt = now
                return .none

            case let .loaded(.failure(failure)):
                state.error = failure.message
                state.isLoading = false
                return .none

            case .dismissError:
                state.error = nil
                return .none

            case .workspaceTapped:
                // Parent feature handles navigation.
                return .none

            case let .selectionChanged(id):
                state.selectedID = id
                if let id {
                    return .send(.workspaceTapped(id))
                }
                return .none
            }
        }
    }
}
