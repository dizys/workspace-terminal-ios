import CoderAPI
import ComposableArchitecture
import Foundation
import Testing
@testable import PTYTransport

@Suite("PTYTransportFactory DI")
struct PTYTransportFactoryTests {
    @Test("test value is a MockPTYTransportFactory by default")
    func testValueIsMock() {
        let box = PTYTransportFactoryBox.testValue
        #expect(box.value is MockPTYTransportFactory)
    }

    @Test("withDependencies override is honored")
    func override() {
        let custom = MockPTYTransportFactory()
        withDependencies {
            $0.ptyTransportFactory = PTYTransportFactoryBox(custom)
        } operation: {
            @Dependency(\.ptyTransportFactory) var box
            #expect(box.value as AnyObject === custom)
        }
    }

    @Test("box callAsFunction proxies to wrapped factory")
    func callProxies() {
        let inner = MockPTYTransportFactory()
        let box = PTYTransportFactoryBox(inner)
        let cfg = PTYTransportConfig(
            agentID: UUID(), reconnectToken: UUID(),
            initialSize: TerminalSize(rows: 24, cols: 80)
        )
        let dep = Deployment(baseURL: URL(string: "https://x.example.com")!, displayName: "x")
        _ = box(deployment: dep, tls: .default, config: cfg, tokenProvider: { nil })
        #expect(inner.produced.count == 1)
    }
}
