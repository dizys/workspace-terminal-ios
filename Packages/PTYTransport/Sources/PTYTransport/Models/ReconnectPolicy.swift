import Foundation

/// Backoff configuration for the reconnect loop.
///
/// Web UI uses `(base: 1s, attempts: 6)` — fine for desktop browsers, too
/// pessimistic for mobile networks that drop for several minutes during
/// elevator rides or subway tunnels. Our default keeps retrying with a
/// 30s ceiling.
///
/// Server-side context: the PTY ring buffer survives 5 minutes of idle
/// (`agent/reconnectingpty/reconnectingpty.go:62-64`), after which a
/// reconnect with the same UUID still works but yields a fresh PTY (no
/// scrollback replay).
public struct ReconnectPolicy: Sendable, Equatable {
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let maxAttempts: Int?
    public let jitter: ClosedRange<Double>

    public init(
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        maxAttempts: Int?,
        jitter: ClosedRange<Double>
    ) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.maxAttempts = maxAttempts
        self.jitter = jitter
    }

    public static let `default` = ReconnectPolicy(
        baseDelay: 1.0,
        maxDelay: 30.0,
        maxAttempts: nil,
        jitter: 0.85...1.15
    )

    /// Delay in seconds before the Nth attempt (1-indexed). Negative or zero
    /// `attempt` collapses to the base delay so callers can pass raw counters
    /// without guarding.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponent = max(0, attempt - 1)
        let raw = baseDelay * pow(2.0, Double(exponent))
        let capped = min(maxDelay, raw)
        return capped * Double.random(in: jitter)
    }
}
