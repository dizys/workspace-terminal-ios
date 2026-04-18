import Foundation

/// One frame on the wire from client to Coder server.
///
/// Wire reality: every WebSocket message is a binary frame whose payload is
/// exactly one JSON object matching this struct. The server reads them with
/// `json.NewDecoder(conn)` so each WS frame must be one complete JSON value.
///
/// References:
///   `.refs/coder/codersdk/workspacesdk/agentconn.go:196-200` — Go struct
///   `.refs/coder/agent/reconnectingpty/reconnectingpty.go:207-234` — server decoder
///   `.refs/coder/coderd/workspaceapps/proxy.go:770` — frames wrapped as binary `net.Conn`
struct ClientFrame: Encodable, Equatable, Sendable {
    var data: String?
    var height: UInt16?
    var width: UInt16?

    /// Wrap user keystrokes (or paste) for transmission.
    ///
    /// We use `String(decoding:as:)` (lossy on invalid UTF-8 → U+FFFD) instead
    /// of throwing — the keystroke hot path must never fail. In practice the
    /// only way to feed invalid UTF-8 here is a programming error or a paste
    /// of binary garbage, both of which the user will see as `?` glyphs.
    static func input(_ bytes: Data) -> ClientFrame {
        ClientFrame(data: String(decoding: bytes, as: UTF8.self), height: nil, width: nil)
    }

    /// Wrap a window-size change. Coder accepts resize either as a standalone
    /// frame or combined with `data` in one frame; we always send standalone.
    static func resize(_ size: TerminalSize) -> ClientFrame {
        ClientFrame(data: nil, height: UInt16(size.rows), width: UInt16(size.cols))
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    func jsonData() throws -> Data {
        try Self.encoder.encode(self)
    }

    func jsonString() throws -> String {
        String(decoding: try jsonData(), as: UTF8.self)
    }
}
