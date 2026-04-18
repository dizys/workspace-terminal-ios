import Foundation
import Security

/// `URLSessionDelegate` that handles per-deployment TLS validation:
///
/// 1. If the system trust store accepts the server's certificate, allow.
/// 2. Otherwise, evaluate the chain against the user-trusted CA set.
/// 3. If `allowsInvalidCertificates` is set, accept anything (dev only).
///
/// Marked `@unchecked Sendable` because `NSObject` subclasses can't be
/// declared `Sendable` directly, but all stored state is immutable.
final class CoderURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    let tls: TLSConfig

    init(tls: TLSConfig) {
        self.tls = tls
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if tls.allowsInvalidCertificates {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        // Try system trust first.
        var error: CFError?
        if SecTrustEvaluateWithError(serverTrust, &error) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        // Fall back to the user-supplied CAs.
        let userCerts = tls.trustedCAs.compactMap { $0.makeSecCertificate() }
        guard !userCerts.isEmpty else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let setStatus = SecTrustSetAnchorCertificates(serverTrust, userCerts as CFArray)
        guard setStatus == errSecSuccess else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        // Don't fall back to the system anchors when the user supplied their own —
        // they've already opted in explicitly.
        SecTrustSetAnchorCertificatesOnly(serverTrust, true)

        var userError: CFError?
        if SecTrustEvaluateWithError(serverTrust, &userError) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
