import Foundation

/// Pure orchestration of the reconnect loop. Decoupled from any transport
/// type so it can be unit-tested with a fake `dial` and an injected `sleep`.
///
/// Caller supplies:
///   - `policy` — backoff/jitter rules
///   - `dial` — open one connection; throws on failure
///   - `sleep` — async pause (real `Task.sleep` in production, deterministic
///     in tests)
///   - `onAttempt` — observability hook (state stream emits via this)
///
/// Returns when `dial` either succeeds (returns normally) or `policy.maxAttempts`
/// is exhausted, at which point it rethrows the last error.
struct Reconnector: Sendable {
    let policy: ReconnectPolicy
    let dial: @Sendable (_ attempt: Int) async throws -> Void
    let sleep: @Sendable (_ seconds: TimeInterval) async throws -> Void
    let onAttempt: @Sendable (_ attempt: Int, _ lastError: Error?) -> Void

    init(
        policy: ReconnectPolicy,
        dial: @escaping @Sendable (_ attempt: Int) async throws -> Void,
        sleep: @escaping @Sendable (_ seconds: TimeInterval) async throws -> Void = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) },
        onAttempt: @escaping @Sendable (_ attempt: Int, _ lastError: Error?) -> Void = { _, _ in }
    ) {
        self.policy = policy
        self.dial = dial
        self.sleep = sleep
        self.onAttempt = onAttempt
    }

    /// Run the loop. Throws the last `dial` error if `maxAttempts` is hit.
    func run() async throws {
        var attempt = 1
        var lastError: Error?
        while true {
            try Task.checkCancellation()
            onAttempt(attempt, lastError)
            do {
                try await dial(attempt)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if let max = policy.maxAttempts, attempt >= max {
                    throw error
                }
                let delay = policy.delay(forAttempt: attempt + 1)
                try await sleep(delay)
                attempt += 1
            }
        }
    }
}
