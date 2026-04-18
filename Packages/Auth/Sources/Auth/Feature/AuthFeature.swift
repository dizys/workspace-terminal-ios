import CoderAPI
import ComposableArchitecture
import Foundation

/// Reducer for the login screen.
///
/// Flow:
/// 1. User enters Coder URL.
/// 2. Reducer validates the URL, builds a `Deployment`, calls
///    `fetchAuthMethods` to discover what's enabled.
/// 3. UI renders the available method buttons.
/// 4. User picks one; reducer invokes the appropriate flow.
/// 5. On success, the resulting `StoredDeployment` is emitted via the
///    `signedIn` action; the parent feature persists it via
///    `DeploymentStore` and transitions to the workspace list.
@Reducer
public struct AuthFeature {
    @ObservableState
    public struct State: Equatable {
        public var urlInput: String = ""
        public var emailInput: String = ""
        public var passwordInput: String = ""
        public var phase: Phase = .enteringURL
        public var availableMethods: [AuthMethod] = []
        public var error: String?
        public var pendingDeployment: Deployment?

        public init(urlInput: String = "") {
            self.urlInput = urlInput
        }
    }

    public enum Phase: Sendable, Equatable {
        case enteringURL
        case probingMethods
        case choosingMethod
        case enteringPassword
        case openingOIDC
        case finalizing
    }

    public enum Action: Equatable {
        case urlInputChanged(String)
        case emailInputChanged(String)
        case passwordInputChanged(String)
        case continueWithURLTapped
        case methodsLoaded(Result<AuthMethods, Failure>)
        case methodTapped(AuthMethod)
        case backToMethodPickerTapped
        case submitPasswordTapped
        case passwordSignInCompleted(Result<StoredDeployment, Failure>)
        case oidcSignInCompleted(Result<StoredDeployment, Failure>)
        case signedIn(StoredDeployment)
        case dismissError
    }

    /// `Equatable` wrapper around any `Error` (TCA `Action` requires `Equatable`).
    public struct Failure: Error, Equatable, Sendable {
        public let message: String
        public init(_ error: any Error) { self.message = (error as? LocalizedError)?.errorDescription ?? "\(error)" }
        public init(message: String) { self.message = message }
    }

    @Dependency(\.coderAPIClientFactory) var clientFactory
    @Dependency(\.passwordLogin) var passwordLogin
    @Dependency(\.oidcFlow) var oidcFlow

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .urlInputChanged(value):
                state.urlInput = value
                return .none

            case let .emailInputChanged(value):
                state.emailInput = value
                return .none

            case let .passwordInputChanged(value):
                state.passwordInput = value
                return .none

            case .continueWithURLTapped:
                guard let deployment = makeDeployment(from: state.urlInput) else {
                    state.error = "Enter a valid https:// URL"
                    return .none
                }
                state.pendingDeployment = deployment
                state.error = nil
                state.phase = .probingMethods
                let factory = clientFactory
                return .run { send in
                    do {
                        let client = factory(deployment, .default)
                        let methods = try await client.fetchAuthMethods()
                        await send(.methodsLoaded(.success(methods)))
                    } catch {
                        await send(.methodsLoaded(.failure(Failure(error))))
                    }
                }

            case let .methodsLoaded(.success(methods)):
                state.availableMethods = methods.enabledMethods
                state.phase = state.availableMethods.isEmpty ? .enteringURL : .choosingMethod
                if state.availableMethods.isEmpty {
                    state.error = "This deployment has no auth methods enabled."
                }
                return .none

            case let .methodsLoaded(.failure(failure)):
                state.error = failure.message
                state.phase = .enteringURL
                return .none

            case let .methodTapped(method):
                switch method {
                case .password:
                    state.phase = .enteringPassword
                    return .none
                case .github, .oidc:
                    guard let deployment = state.pendingDeployment else { return .none }
                    state.phase = .openingOIDC
                    let provider: OIDCFlow.Provider = method == .github ? .github : .oidc
                    let flow = oidcFlow
                    return .run { send in
                        do {
                            let stored = try await flow.signIn(deployment: deployment, provider: provider)
                            await send(.oidcSignInCompleted(.success(stored)))
                        } catch {
                            await send(.oidcSignInCompleted(.failure(Failure(error))))
                        }
                    }
                }

            case .backToMethodPickerTapped:
                state.passwordInput = ""
                state.error = nil
                state.phase = .choosingMethod
                return .none

            case .submitPasswordTapped:
                guard let deployment = state.pendingDeployment else { return .none }
                let email = state.emailInput
                let password = state.passwordInput
                state.phase = .finalizing
                let login = passwordLogin
                return .run { send in
                    do {
                        let stored = try await login.signIn(
                            deployment: deployment,
                            email: email,
                            password: password,
                            tls: .default
                        )
                        await send(.passwordSignInCompleted(.success(stored)))
                    } catch {
                        await send(.passwordSignInCompleted(.failure(Failure(error))))
                    }
                }

            case let .passwordSignInCompleted(.success(stored)),
                 let .oidcSignInCompleted(.success(stored)):
                return .send(.signedIn(stored))

            case let .passwordSignInCompleted(.failure(failure)),
                 let .oidcSignInCompleted(.failure(failure)):
                state.error = failure.message
                state.phase = .choosingMethod
                return .none

            case .signedIn:
                return .none

            case .dismissError:
                state.error = nil
                return .none
            }
        }
    }

    /// Validate `input` and produce a Deployment with an inferred display name.
    func makeDeployment(from input: String) -> Deployment? {
        var trimmed = input.trimmingCharacters(in: .whitespaces)
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://\(trimmed)"
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty
        else { return nil }
        return Deployment(baseURL: url, displayName: host)
    }
}
