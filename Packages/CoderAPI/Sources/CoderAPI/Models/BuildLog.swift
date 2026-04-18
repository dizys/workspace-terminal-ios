import Foundation

/// A single line of provisioner build log output, streamed from
/// `GET /api/v2/workspacebuilds/{id}/logs?follow=true`.
public struct BuildLog: Sendable, Hashable, Codable, Identifiable {
    public let id: Int64
    public let createdAt: Date
    public let logSource: Source
    public let logLevel: Level
    public let stage: String
    public let output: String

    public init(
        id: Int64,
        createdAt: Date,
        logSource: Source,
        logLevel: Level,
        stage: String,
        output: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.logSource = logSource
        self.logLevel = logLevel
        self.stage = stage
        self.output = output
    }

    public enum Source: String, Sendable, Hashable, Codable, CaseIterable {
        case provisionerDaemon = "provisioner_daemon"
        case provisioner
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Source(rawValue: raw) ?? .unknown
        }
    }

    public enum Level: String, Sendable, Hashable, Codable, CaseIterable {
        case trace
        case debug
        case info
        case warn
        case error
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Level(rawValue: raw) ?? .unknown
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case logSource = "log_source"
        case logLevel = "log_level"
        case stage
        case output
    }
}
