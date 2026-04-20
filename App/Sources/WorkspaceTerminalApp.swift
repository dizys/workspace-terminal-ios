import AppFeature
import Auth
import CoderAPI
import ComposableArchitecture
import SwiftUI
import TerminalFeature
import WorkspaceFeature

@main
struct WorkspaceTerminalApp: App {
    let store: StoreOf<AppFeature>

    init() {
        let keychain: any KeychainClient
        let deploymentStore: any DeploymentStore

        #if DEBUG
        if let token = ProcessInfo.processInfo.environment["UITEST_SESSION_TOKEN"],
           let urlString = ProcessInfo.processInfo.environment["UITEST_CODER_URL"],
           let url = URL(string: urlString)
        {
            let mem = InMemoryKeychainClient()
            let store = LiveDeploymentStore(keychain: mem)
            let deployment = StoredDeployment(
                deployment: Deployment(
                    baseURL: url,
                    displayName: url.host ?? "Test",
                    username: ProcessInfo.processInfo.environment["UITEST_USERNAME"] ?? "admin"
                ),
                token: SessionToken(token)
            )
            Task { try? await store.upsertActive(deployment) }
            keychain = mem
            deploymentStore = store
        } else {
            keychain = LiveKeychainClient()
            deploymentStore = LiveDeploymentStore(keychain: keychain)
        }
        #else
        keychain = LiveKeychainClient()
        deploymentStore = LiveDeploymentStore(keychain: keychain)
        #endif
        _ = keychain

        let userAgent = CoderAPI.userAgent

        let apiClientProvider = AuthenticatedAPIClientProvider { [deploymentStore, userAgent] in
            guard let stored = try? await deploymentStore.activeDeployment() else { return nil }
            return LiveCoderAPIClient(
                deployment: stored.deployment,
                tls: stored.tlsConfig,
                userAgent: userAgent,
                tokenProvider: { stored.token }
            )
        }

        let tokenProvider = AuthenticatedSessionTokenProvider { [deploymentStore] in
            (try? await deploymentStore.activeDeployment())?.token
        }

        let oidcSession = LiveWebAuthSession {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first { $0.isKeyWindow }
                ?? UIWindow()
        }

        store = withDependencies {
            $0.deploymentStore = DeploymentStoreDependency(deploymentStore)
            $0.authenticatedAPIClient = apiClientProvider
            $0.authenticatedSessionToken = tokenProvider
            $0.coderAPIClientFactory = .init { deployment, tls in
                LiveCoderAPIClient(
                    deployment: deployment,
                    tls: tls,
                    userAgent: userAgent,
                    tokenProvider: { nil }
                )
            }
            $0.passwordLogin = PasswordLogin(userAgent: userAgent)
            $0.tokenLogin = TokenLogin(userAgent: userAgent)
            $0.oidcFlow = OIDCFlow(userAgent: userAgent, session: oidcSession)
        } operation: {
            Store(initialState: AppFeature.State()) { AppFeature() }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
        }
    }
}
