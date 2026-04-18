import CoderAPI
import Foundation
import Testing
@testable import PTYTransport

/// Param order + scheme conversion verified against `cli/exp_rpty.go:154` and
/// `codersdk/workspacesdk/workspacesdk.go:341` in the upstream Go source.
@Suite("PTYURLBuilder")
struct URLBuilderTests {
    private let agentID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let token   = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    private func makeDeployment(_ urlString: String) -> Deployment {
        Deployment(baseURL: URL(string: urlString)!, displayName: "test")
    }

    @Test("builds wss:// URL with reconnect, width, height, command in CLI order")
    func minimalConfig() {
        let cfg = PTYTransportConfig(
            agentID: agentID,
            reconnectToken: token,
            initialSize: TerminalSize(rows: 24, cols: 80)
        )
        let url = PTYURLBuilder.makeURL(deployment: makeDeployment("https://coder.example.com"), config: cfg)
        #expect(url.scheme == "wss")
        #expect(url.host == "coder.example.com")
        #expect(url.path == "/api/v2/workspaceagents/\(agentID.uuidString.lowercased())/pty")
        let q = url.queryParams
        #expect(q == [
            "reconnect": token.uuidString.lowercased(),
            "width": "80",
            "height": "24",
            "command": "",
        ])
    }

    @Test("http:// becomes ws:// (dev deployments)")
    func httpDowngrade() {
        let cfg = PTYTransportConfig(agentID: agentID, reconnectToken: token,
                                     initialSize: TerminalSize(rows: 24, cols: 80))
        let url = PTYURLBuilder.makeURL(deployment: makeDeployment("http://localhost:3000"), config: cfg)
        #expect(url.scheme == "ws")
        #expect(url.port == 3000)
    }

    @Test("appends container, container_user, backend_type when set")
    func devcontainerParams() {
        let cfg = PTYTransportConfig(
            agentID: agentID, reconnectToken: token,
            initialSize: TerminalSize(rows: 30, cols: 100),
            command: "/bin/bash",
            container: "devc-1",
            containerUser: "vscode",
            backendType: .buffered
        )
        let url = PTYURLBuilder.makeURL(deployment: makeDeployment("https://coder.example.com"), config: cfg)
        let q = url.queryParams
        #expect(q["container"] == "devc-1")
        #expect(q["container_user"] == "vscode")
        #expect(q["backend_type"] == "buffered")
        #expect(q["command"] == "/bin/bash")
    }

    @Test("baseURL with trailing slash is normalized")
    func trailingSlash() {
        let cfg = PTYTransportConfig(agentID: agentID, reconnectToken: token,
                                     initialSize: TerminalSize(rows: 24, cols: 80))
        let url = PTYURLBuilder.makeURL(deployment: makeDeployment("https://coder.example.com/"), config: cfg)
        // No double-slash in path
        #expect(url.path == "/api/v2/workspaceagents/\(agentID.uuidString.lowercased())/pty")
    }

    @Test("baseURL with subpath prefix is preserved")
    func subpathPrefix() {
        let cfg = PTYTransportConfig(agentID: agentID, reconnectToken: token,
                                     initialSize: TerminalSize(rows: 24, cols: 80))
        let url = PTYURLBuilder.makeURL(deployment: makeDeployment("https://corp.com/coder"), config: cfg)
        #expect(url.path == "/coder/api/v2/workspaceagents/\(agentID.uuidString.lowercased())/pty")
    }
}

private extension URL {
    /// Decoded query params. Returns `[:]` if there are none.
    var queryParams: [String: String] {
        guard let items = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        var dict: [String: String] = [:]
        for item in items { dict[item.name] = item.value ?? "" }
        return dict
    }
}
