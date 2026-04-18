import Foundation
import Testing
@testable import CoderAPI

@Suite("Workspace endpoints")
struct WorkspaceEndpointTests {
    @Test("listMyWorkspaces decodes the workspaces array")
    func list() async throws {
        let stub = StubURLSession()
        stub.register(
            method: "GET",
            pathSuffix: "/api/v2/workspaces",
            response: .init(body: Fixtures.json(workspacesJSON))
        )
        let workspaces = try await Fixtures.client(session: stub.session).listMyWorkspaces()
        #expect(workspaces.count == 1)
        #expect(workspaces[0].name == "dev")
        #expect(workspaces[0].latestBuild.status == .running)
    }

    @Test("createBuild posts the transition and decodes the new build")
    func createBuild() async throws {
        let stub = StubURLSession()
        let workspaceID = UUID()
        stub.register(
            method: "POST",
            pathSuffix: "/api/v2/workspaces/\(workspaceID.uuidString.lowercased())/builds",
            response: .init(body: Fixtures.json(buildJSON))
        )
        let build = try await Fixtures.client(session: stub.session)
            .createBuild(workspaceID: workspaceID, transition: .start)
        #expect(build.transition == .start)
        #expect(build.buildNumber == 17)
    }
}

// MARK: - Fixtures

private let buildJSON = #"""
{
  "id": "11111111-1111-1111-1111-111111111111",
  "workspace_id": "22222222-2222-2222-2222-222222222222",
  "workspace_name": "dev",
  "workspace_owner_id": "33333333-3333-3333-3333-333333333333",
  "workspace_owner_name": "alice",
  "template_version_id": "44444444-4444-4444-4444-444444444444",
  "build_number": 17,
  "transition": "start",
  "initiator_id": "33333333-3333-3333-3333-333333333333",
  "initiator_name": "alice",
  "job": {
    "id": "55555555-5555-5555-5555-555555555555",
    "status": "succeeded",
    "created_at": "2026-04-18T03:00:00Z"
  },
  "reason": "initiator",
  "resources": [],
  "created_at": "2026-04-18T03:00:00Z",
  "updated_at": "2026-04-18T03:01:00Z"
}
"""#

private let workspacesJSON = #"""
{
  "count": 1,
  "workspaces": [
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "name": "dev",
      "owner_id": "33333333-3333-3333-3333-333333333333",
      "owner_name": "alice",
      "template_id": "66666666-6666-6666-6666-666666666666",
      "template_name": "ubuntu",
      "created_at": "2026-04-15T10:00:00Z",
      "updated_at": "2026-04-18T03:01:00Z",
      "outdated": false,
      "latest_build": \#(buildJSON)
    }
  ]
}
"""#
