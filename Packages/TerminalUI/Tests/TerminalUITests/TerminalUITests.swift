import Testing
@testable import TerminalUI

@Suite("TerminalUI smoke")
struct TerminalUITests {
    @Test("Default key bar contains esc and tab")
    func defaultKeyBar() {
        #expect(KeyBarConfig.default.topRow.contains("esc"))
        #expect(KeyBarConfig.default.topRow.contains("tab"))
    }

    @Test("Default modifiers include ctrl")
    func defaultModifiers() {
        #expect(KeyBarConfig.default.modifiers.contains("ctrl"))
    }
}
