import Foundation
import Testing
@testable import CoderAPI

@Suite("WorkspaceBuild status mapping")
struct WorkspaceBuildStatusTests {
    @Test("succeeded + start -> running")
    func succeededStart() {
        #expect(ProvisionerJobStatus.succeeded.workspaceBuildStatus(transition: .start) == .running)
    }

    @Test("succeeded + stop -> stopped")
    func succeededStop() {
        #expect(ProvisionerJobStatus.succeeded.workspaceBuildStatus(transition: .stop) == .stopped)
    }

    @Test("running + start -> starting")
    func runningStart() {
        #expect(ProvisionerJobStatus.running.workspaceBuildStatus(transition: .start) == .starting)
    }

    @Test("running + stop -> stopping")
    func runningStop() {
        #expect(ProvisionerJobStatus.running.workspaceBuildStatus(transition: .stop) == .stopping)
    }

    @Test("failed -> failed regardless of transition")
    func failed() {
        for transition in WorkspaceBuild.Transition.allCases {
            #expect(ProvisionerJobStatus.failed.workspaceBuildStatus(transition: transition) == .failed)
        }
    }

    @Test("Unknown values decode to .unknown")
    func unknownValues() throws {
        let agent = try JSONCoders.decoder.decode(WorkspaceAgent.Status.self, from: Data(#""freshly_invented""#.utf8))
        #expect(agent == .unknown)
        let lifecycle = try JSONCoders.decoder.decode(WorkspaceAgent.LifecycleState.self, from: Data(#""mystery""#.utf8))
        #expect(lifecycle == .unknown)
    }
}
