import AppFeature
import Auth
import CoderAPI
import ComposableArchitecture
import SwiftUI
import WorkspaceFeature

@main
struct WorkspaceTerminalApp: App {
    let store: StoreOf<AppFeature>

    init() {
        let keychain = LiveKeychainClient()
        let deploymentStore = LiveDeploymentStore(keychain: keychain)
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
        let appBuild = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        let userAgent = CoderAPI.userAgent(appVersion: appVersion, build: appBuild)

        let apiClientProvider = AuthenticatedAPIClientProvider { [deploymentStore, userAgent] in
            guard let stored = try? await deploymentStore.activeDeployment() else { return nil }
            return LiveCoderAPIClient(
                deployment: stored.deployment,
                tls: stored.tlsConfig,
                userAgent: userAgent,
                tokenProvider: { stored.token }
            )
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
            $0.coderAPIClientFactory = .init { deployment, tls in
                LiveCoderAPIClient(
                    deployment: deployment,
                    tls: tls,
                    userAgent: userAgent,
                    tokenProvider: { nil }
                )
            }
            $0.passwordLogin = PasswordLogin(userAgent: userAgent)
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
