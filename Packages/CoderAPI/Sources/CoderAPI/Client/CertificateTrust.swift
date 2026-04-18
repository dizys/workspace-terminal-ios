import Foundation
import Security

/// User-managed TLS trust policy for a deployment.
///
/// Self-hosted Coder deployments often use private CAs that aren't in the
/// system trust store. This type lets the user opt-in to trusting a specific
/// CA certificate by uploading it once; the cert is stored in the Keychain
/// alongside the deployment record (in the Auth package).
public struct CertificateTrust: Sendable, Hashable, Codable {
    /// DER-encoded CA certificate the user has explicitly trusted.
    public let derEncodedCertificate: Data

    public init(derEncodedCertificate: Data) {
        self.derEncodedCertificate = derEncodedCertificate
    }

    /// Build a `SecCertificate` for use in TLS validation.
    public func makeSecCertificate() -> SecCertificate? {
        SecCertificateCreateWithData(nil, derEncodedCertificate as CFData)
    }
}

/// Configuration for TLS handling on a per-deployment basis.
public struct TLSConfig: Sendable {
    /// Additional trusted root CA certs the user has opted into.
    public let trustedCAs: [CertificateTrust]

    /// If true, accept any TLS certificate (development only — never default).
    public let allowsInvalidCertificates: Bool

    public init(trustedCAs: [CertificateTrust] = [], allowsInvalidCertificates: Bool = false) {
        self.trustedCAs = trustedCAs
        self.allowsInvalidCertificates = allowsInvalidCertificates
    }

    public static let `default` = TLSConfig()
}
