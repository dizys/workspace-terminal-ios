import Testing
@testable import PTYTransport

@Suite("ReconnectPolicy")
struct ReconnectPolicyTests {
    @Test("default matches mobile-safe values (web UI uses 1s base + 6 attempts; we keep retrying)")
    func defaultValues() {
        let p = ReconnectPolicy.default
        #expect(p.baseDelay == 1.0)
        #expect(p.maxDelay == 30.0)
        #expect(p.maxAttempts == nil)
        #expect(p.jitter == 0.85...1.15)
    }

    @Test("delay grows exponentially and caps at maxDelay")
    func exponentialBackoffWithCap() {
        let p = ReconnectPolicy(baseDelay: 1, maxDelay: 8, maxAttempts: nil, jitter: 1.0...1.0)
        #expect(p.delay(forAttempt: 1) == 1)
        #expect(p.delay(forAttempt: 2) == 2)
        #expect(p.delay(forAttempt: 3) == 4)
        #expect(p.delay(forAttempt: 4) == 8)
        #expect(p.delay(forAttempt: 5) == 8)   // capped
        #expect(p.delay(forAttempt: 99) == 8)  // capped
    }

    @Test("delay applies jitter within configured range")
    func jitterWithinRange() {
        let p = ReconnectPolicy(baseDelay: 10, maxDelay: 100, maxAttempts: nil, jitter: 0.5...1.5)
        // attempt 2 → base 20, jitter 10..30
        for _ in 0..<200 {
            let d = p.delay(forAttempt: 2)
            #expect(d >= 10)
            #expect(d <= 30)
        }
    }

    @Test("attempt 0 or negative still yields baseDelay (defensive)")
    func nonPositiveAttemptIsBase() {
        let p = ReconnectPolicy(baseDelay: 2, maxDelay: 100, maxAttempts: nil, jitter: 1.0...1.0)
        #expect(p.delay(forAttempt: 0) == 2)
        #expect(p.delay(forAttempt: -5) == 2)
    }
}
