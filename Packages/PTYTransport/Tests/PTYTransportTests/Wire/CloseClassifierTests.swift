import Testing
@testable import PTYTransport

/// Close-code semantics from the upstream Go server:
///   1000        — normal close (we send this on userInitiated)
///   1001 + "Ping failed" — server timeout (`coderd/httpapi/websocket.go:53`)
///   1011 + "dial workspace agent: …" — agent unreachable (`coderd/workspaceapps/proxy.go:776`)
///   1011 + "dial: …"                 — agent unreachable (`coderd/workspaceapps/proxy.go:789`)
///   anything else                    — fatal
@Suite("CloseClassifier")
struct CloseClassifierTests {
    @Test("normal close (1000) → userInitiated")
    func normalClose() {
        #expect(CloseClassifier.classify(code: 1000, reason: "") == .userInitiated)
    }

    @Test("going-away (1001) Ping failed → serverTimeout (transient)")
    func goingAwayPingFailed() {
        #expect(CloseClassifier.classify(code: 1001, reason: "Ping failed") == .serverTimeout)
    }

    @Test("internal error (1011) with 'dial workspace agent' → agentUnreachable")
    func internalErrorDialWorkspaceAgent() {
        let r = CloseClassifier.classify(
            code: 1011,
            reason: "dial workspace agent: tailnet unreachable"
        )
        #expect(r == .agentUnreachable(detail: "dial workspace agent: tailnet unreachable"))
    }

    @Test("internal error (1011) with 'dial:' → agentUnreachable")
    func internalErrorDialGeneric() {
        let r = CloseClassifier.classify(code: 1011, reason: "dial: io timeout")
        #expect(r == .agentUnreachable(detail: "dial: io timeout"))
    }

    @Test("internal error (1011) with non-dial reason → fatal")
    func internalErrorNonDial() {
        let r = CloseClassifier.classify(code: 1011, reason: "internal panic")
        #expect(r == .fatal(code: 1011, reason: "internal panic"))
    }

    @Test("policy violation (1008) → fatal")
    func policyViolation() {
        #expect(CloseClassifier.classify(code: 1008, reason: "policy") == .fatal(code: 1008, reason: "policy"))
    }

    @Test("HTTP 401 on upgrade → authExpired")
    func http401() {
        #expect(CloseClassifier.classifyHTTPHandshake(status: 401) == .authExpired)
    }

    @Test("HTTP 403 on upgrade → authExpired (treat as recoverable via re-auth)")
    func http403() {
        #expect(CloseClassifier.classifyHTTPHandshake(status: 403) == .authExpired)
    }

    @Test("HTTP 5xx on upgrade → fatal")
    func http500() {
        #expect(CloseClassifier.classifyHTTPHandshake(status: 503) == .fatal(code: 503, reason: "HTTP 503"))
    }
}
