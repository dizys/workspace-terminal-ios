import Foundation
import Testing
@testable import PTYTransport

@Suite("Reconnector")
struct ReconnectorTests {
    private struct FakeError: Error, Equatable {
        let id: Int
    }

    @Test("succeeds on first try — no backoff invoked")
    func succeedsImmediately() async throws {
        let sleepCalls = LockBox<[TimeInterval]>([])
        let attempts = LockBox<[Int]>([])
        let r = Reconnector(
            policy: ReconnectPolicy(baseDelay: 1, maxDelay: 10, maxAttempts: 3, jitter: 1.0...1.0),
            dial: { _ in /* OK */ },
            sleep: { s in sleepCalls.mutate { $0.append(s) } },
            onAttempt: { attempt, _ in attempts.mutate { $0.append(attempt) } }
        )
        try await r.run()
        #expect(sleepCalls.value.isEmpty)
        #expect(attempts.value == [1])
    }

    @Test("retries until success then stops")
    func retriesUntilSuccess() async throws {
        let attempts = LockBox<[Int]>([])
        let sleeps = LockBox<[TimeInterval]>([])
        let dialCount = LockBox<Int>(0)

        let r = Reconnector(
            policy: ReconnectPolicy(baseDelay: 1, maxDelay: 10, maxAttempts: nil, jitter: 1.0...1.0),
            dial: { _ in
                let n = dialCount.mutate { $0 += 1; return $0 }
                if n < 3 { throw FakeError(id: n) }
            },
            sleep: { s in sleeps.mutate { $0.append(s) } },
            onAttempt: { a, _ in attempts.mutate { $0.append(a) } }
        )
        try await r.run()
        #expect(attempts.value == [1, 2, 3])
        // Sleeps before attempt 2 and attempt 3 only.
        #expect(sleeps.value.count == 2)
    }

    @Test("rethrows last error when maxAttempts exhausted")
    func rethrowsAfterMaxAttempts() async throws {
        let r = Reconnector(
            policy: ReconnectPolicy(baseDelay: 0.001, maxDelay: 0.001, maxAttempts: 3, jitter: 1.0...1.0),
            dial: { attempt in throw FakeError(id: attempt) },
            sleep: { _ in /* instant */ },
            onAttempt: { _, _ in }
        )
        do {
            try await r.run()
            Issue.record("Expected throw")
        } catch let e as FakeError {
            #expect(e.id == 3)
        }
    }

    @Test("honors task cancellation")
    func cancellation() async throws {
        let task = Task {
            let r = Reconnector(
                policy: ReconnectPolicy(baseDelay: 10, maxDelay: 10, maxAttempts: nil, jitter: 1.0...1.0),
                dial: { _ in throw FakeError(id: 1) },
                sleep: { _ in try await Task.sleep(nanoseconds: 100_000_000) },
                onAttempt: { _, _ in }
            )
            try await r.run()
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()
        let result = await task.result
        switch result {
        case .success: Issue.record("Expected cancellation")
        case .failure: break // CancellationError or sleep cancellation — both fine
        }
    }
}

/// Simple thread-safe box for tests.
final class LockBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value
    init(_ value: Value) { self._value = value }
    var value: Value { lock.lock(); defer { lock.unlock() }; return _value }
    @discardableResult
    func mutate<R>(_ body: (inout Value) -> R) -> R {
        lock.lock(); defer { lock.unlock() }
        return body(&_value)
    }
}
