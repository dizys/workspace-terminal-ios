import Foundation

/// Shared test helpers: deterministic clocks, fake URLProtocols, fixture loaders.
public enum TestSupport {}

/// A monotonically advancing clock for tests that need predictable timing
/// without pulling in the full TCA `TestClock`.
public actor MonotonicTestClock {
    public private(set) var now: Date

    public init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.now = start
    }

    public func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
