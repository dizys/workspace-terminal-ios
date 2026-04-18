import Foundation

/// Typed errors surfaced by `PTYTransport`. Inbound `AsyncThrowingStream`
/// finishes with one of these on terminal failure; transient close codes are
/// instead surfaced via `state` as `.reconnecting(...)` and the transport
/// recovers.
public enum PTYError: Error, Sendable, Equatable {
    /// Pre-upgrade HTTP failure — server responded with non-101.
    case handshakeFailed(status: Int?, detail: String)
    /// WebSocket terminated; classify from the WS close code.
    case closed(CloseReason)
    /// JSON encoder failed (very rare — caller fed un-encodable data).
    case encodingFailed(String)
    /// Caller cancelled the operation.
    case cancelled
}
