import Foundation

/// Lifecycle of a `PTYTransport` from the consumer's perspective.
///
/// Emitted on the `state` AsyncStream as the transport progresses through:
///   `.idle` → `.connecting(1)` → `.connected`
/// On a transient close: `.reconnecting(N, lastError)` → `.connecting(N+1)` → `.connected`
/// On a final close: `.closed(reason)`
public enum ConnectionState: Sendable, Equatable {
    case idle
    case connecting(attempt: Int)
    case connected
    case reconnecting(attempt: Int, lastError: PTYError?)
    case closed(CloseReason)
}
