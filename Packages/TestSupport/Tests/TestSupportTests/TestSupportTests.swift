import Foundation
import Testing
@testable import TestSupport

@Suite("TestSupport smoke")
struct TestSupportTests {
    @Test("MonotonicTestClock advances")
    func clockAdvances() async {
        let clock = MonotonicTestClock()
        let start = await clock.now
        await clock.advance(by: 10)
        let end = await clock.now
        #expect(end.timeIntervalSince(start) == 10)
    }
}
