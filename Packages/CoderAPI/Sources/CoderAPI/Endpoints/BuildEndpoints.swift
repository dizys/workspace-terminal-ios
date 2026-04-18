import Foundation

extension LiveCoderAPIClient {
    public func createBuild(
        workspaceID: UUID,
        transition: WorkspaceBuild.Transition
    ) async throws -> WorkspaceBuild {
        let body = CreateBuildRequest(transition: transition)
        let data: Data
        do {
            data = try JSONCoders.encoder.encode(body)
        } catch {
            throw CoderAPIError.encoding(reason: String(describing: error))
        }
        return try await http.send(HTTPRequest(
            method: .post,
            path: "/workspaces/\(workspaceID.uuidString.lowercased())/builds",
            body: data,
            idempotencyKey: UUID().uuidString
        ))
    }

    public func fetchBuild(id: UUID) async throws -> WorkspaceBuild {
        try await http.send(HTTPRequest(
            method: .get,
            path: "/workspacebuilds/\(id.uuidString.lowercased())"
        ))
    }

    /// Stream provisioner build logs as decoded `BuildLog` values.
    /// Set `follow: true` to keep the connection open as new logs arrive.
    public func streamBuildLogs(buildID: UUID, follow: Bool) async throws -> AsyncThrowingStream<BuildLog, Error> {
        var query: [URLQueryItem] = []
        if follow {
            query.append(URLQueryItem(name: "follow", value: "true"))
        }
        let lineStream = try await http.stream(HTTPRequest(
            method: .get,
            path: "/workspacebuilds/\(buildID.uuidString.lowercased())/logs",
            query: query
        ))
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in lineStream {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { continue }
                        guard let data = trimmed.data(using: .utf8) else { continue }
                        do {
                            let log = try JSONCoders.decoder.decode(BuildLog.self, from: data)
                            continuation.yield(log)
                        } catch {
                            // Skip malformed lines (server may send keepalives or partial frames)
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
