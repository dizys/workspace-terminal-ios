import CoderAPI
import Foundation

/// A deployment + the credentials persisted for it.
///
/// Persisted in the Keychain by `DeploymentStore`. The `token` and any
/// `tlsConfig` user-trusted CAs are sensitive; the rest is only sensitive
/// because it identifies which deployment a user has signed into.
public struct StoredDeployment: Sendable, Hashable, Codable, Identifiable {
    public let deployment: Deployment
    public var token: SessionToken
    public var trustedCAs: [CertificateTrust]

    public var id: UUID { deployment.id }

    public init(
        deployment: Deployment,
        token: SessionToken,
        trustedCAs: [CertificateTrust] = []
    ) {
        self.deployment = deployment
        self.token = token
        self.trustedCAs = trustedCAs
    }

    public var tlsConfig: TLSConfig {
        TLSConfig(trustedCAs: trustedCAs)
    }
}
