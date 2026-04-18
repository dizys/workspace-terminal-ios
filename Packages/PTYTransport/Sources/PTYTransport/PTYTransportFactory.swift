import CoderAPI
import ComposableArchitecture
import Foundation

/// Live implementation of `PTYTransportFactory` — wraps each call in a fresh
/// `LivePTYTransport` actor instance.
public struct LivePTYTransportFactory: PTYTransportFactory {
    public let userAgent: String

    public init(userAgent: String) {
        self.userAgent = userAgent
    }

    public func make(
        deployment: Deployment,
        tls: TLSConfig,
        config: PTYTransportConfig,
        tokenProvider: @escaping @Sendable () async -> SessionToken?
    ) -> any PTYTransport {
        LivePTYTransport(
            deployment: deployment,
            tls: tls,
            config: config,
            tokenProvider: tokenProvider,
            userAgent: userAgent
        )
    }
}

/// Box around `any PTYTransportFactory` so it conforms to `DependencyKey`.
public struct PTYTransportFactoryBox: Sendable {
    public let value: any PTYTransportFactory

    public init(_ value: any PTYTransportFactory) {
        self.value = value
    }

    public func callAsFunction(
        deployment: Deployment,
        tls: TLSConfig,
        config: PTYTransportConfig,
        tokenProvider: @escaping @Sendable () async -> SessionToken?
    ) -> any PTYTransport {
        value.make(deployment: deployment, tls: tls, config: config, tokenProvider: tokenProvider)
    }
}

extension PTYTransportFactoryBox: DependencyKey {
    public static let liveValue = PTYTransportFactoryBox(
        LivePTYTransportFactory(userAgent: "WorkspaceTerminal-iOS")
    )
    public static let testValue = PTYTransportFactoryBox(MockPTYTransportFactory())
}

extension DependencyValues {
    public var ptyTransportFactory: PTYTransportFactoryBox {
        get { self[PTYTransportFactoryBox.self] }
        set { self[PTYTransportFactoryBox.self] = newValue }
    }
}
