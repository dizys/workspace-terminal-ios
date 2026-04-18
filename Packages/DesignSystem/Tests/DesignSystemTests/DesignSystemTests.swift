import Testing
@testable import DesignSystem

@Suite("DesignSystem smoke")
struct DesignSystemTests {
    @Test("Bundled themes include system")
    func bundledThemesIncludeSystem() {
        #expect(TerminalTheme.bundled.contains(.system))
    }

    @Test("Bundled themes are unique by id")
    func bundledThemesUnique() {
        let ids = TerminalTheme.bundled.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
