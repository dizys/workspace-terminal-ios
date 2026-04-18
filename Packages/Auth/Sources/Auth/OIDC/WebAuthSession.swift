#if canImport(AuthenticationServices) && os(iOS)
import AuthenticationServices
import Foundation

/// `OIDCFlow.AuthSession` backed by `ASWebAuthenticationSession`.
///
/// `presentationContextProvider` is required on iOS; the app supplies one
/// that returns the current key window.
public final class LiveWebAuthSession: NSObject, OIDCFlow.AuthSession,
    ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {

    public let presentationAnchor: @MainActor () -> ASPresentationAnchor
    public let prefersEphemeralBrowserSession: Bool

    public init(
        prefersEphemeralBrowserSession: Bool = false,
        presentationAnchor: @escaping @MainActor () -> ASPresentationAnchor
    ) {
        self.presentationAnchor = presentationAnchor
        self.prefersEphemeralBrowserSession = prefersEphemeralBrowserSession
    }

    public func start(authURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error {
                    if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                        continuation.resume(throwing: OIDCFlow.OIDCError.userCanceled)
                    } else {
                        continuation.resume(throwing: OIDCFlow.OIDCError.underlying(error.localizedDescription))
                    }
                } else {
                    continuation.resume(throwing: OIDCFlow.OIDCError.underlying("Unknown ASWebAuthenticationSession failure"))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = prefersEphemeralBrowserSession
            Task { @MainActor in
                _ = session.start()
            }
        }
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { presentationAnchor() }
    }
}
#endif
