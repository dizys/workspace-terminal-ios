import CoderAPI
import ComposableArchitecture
import Foundation

/// Single-workspace detail screen. Shows agents and exposes
/// start/stop/restart lifecycle actions; streams build logs while a
/// transition is in flight.
@Reducer
public struct WorkspaceDetailFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let workspaceID: UUID
        public var workspace: Workspace?
        public var isLoading: Bool = false
        public var pendingTransition: WorkspaceBuild.Transition?
        public var buildLogs: [BuildLog] = []
        public var error: String?

        public var id: UUID { workspaceID }

        public init(workspaceID: UUID, workspace: Workspace? = nil) {
            self.workspaceID = workspaceID
            self.workspace = workspace
        }

        /// Convenience: list of all agents (parent + child devcontainer agents)
        /// flattened from all resources.
        public var agents: [WorkspaceAgent] {
            guard let workspace else { return [] }
            return workspace.latestBuild.resources.flatMap(\.agents)
        }
    }

    public enum Action: Equatable {
        case onAppear
        case refresh
        case workspaceLoaded(Result<Workspace, WorkspaceFailure>)
        case startTapped
        case stopTapped
        case restartTapped
        case buildCreated(Result<WorkspaceBuild, WorkspaceFailure>)
        case buildLogReceived(BuildLog)
        case buildLogStreamFinished
        case dismissError
    }

    @Dependency(\.authenticatedAPIClient) var apiClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear, .refresh:
                state.isLoading = true
                let id = state.workspaceID
                let client = apiClient
                return .run { send in
                    guard let api = await client() else {
                        await send(.workspaceLoaded(.failure(WorkspaceFailure(message: "Not signed in"))))
                        return
                    }
                    do {
                        let ws = try await api.fetchWorkspace(id: id)
                        await send(.workspaceLoaded(.success(ws)))
                    } catch {
                        await send(.workspaceLoaded(.failure(WorkspaceFailure(error))))
                    }
                }

            case let .workspaceLoaded(.success(ws)):
                state.workspace = ws
                state.isLoading = false
                return .none

            case let .workspaceLoaded(.failure(failure)):
                state.error = failure.message
                state.isLoading = false
                return .none

            case .startTapped:
                return submitBuild(state: &state, transition: .start)

            case .stopTapped:
                return submitBuild(state: &state, transition: .stop)

            case .restartTapped:
                // Restart is two builds: stop, then start. Coder server
                // doesn't expose a single 'restart' transition; we drive
                // .stop here and the user can re-tap start when stopped.
                // Future: chain automatically.
                return submitBuild(state: &state, transition: .stop)

            case let .buildCreated(.success(build)):
                state.pendingTransition = build.transition
                state.buildLogs = []
                let buildID = build.id
                let client = apiClient
                return .run { send in
                    guard let api = await client() else { return }
                    do {
                        let stream = try await api.streamBuildLogs(buildID: buildID, follow: true)
                        for try await log in stream {
                            await send(.buildLogReceived(log))
                        }
                        await send(.buildLogStreamFinished)
                    } catch {
                        await send(.buildLogStreamFinished)
                    }
                }

            case let .buildCreated(.failure(failure)):
                state.error = failure.message
                return .none

            case let .buildLogReceived(log):
                state.buildLogs.append(log)
                return .none

            case .buildLogStreamFinished:
                state.pendingTransition = nil
                return .send(.refresh)

            case .dismissError:
                state.error = nil
                return .none
            }
        }
    }

    private func submitBuild(state: inout State, transition: WorkspaceBuild.Transition) -> Effect<Action> {
        guard let workspace = state.workspace else { return .none }
        state.pendingTransition = transition
        state.error = nil
        let id = workspace.id
        let client = apiClient
        return .run { send in
            guard let api = await client() else {
                await send(.buildCreated(.failure(WorkspaceFailure(message: "Not signed in"))))
                return
            }
            do {
                let build = try await api.createBuild(workspaceID: id, transition: transition)
                await send(.buildCreated(.success(build)))
            } catch {
                await send(.buildCreated(.failure(WorkspaceFailure(error))))
            }
        }
    }
}
