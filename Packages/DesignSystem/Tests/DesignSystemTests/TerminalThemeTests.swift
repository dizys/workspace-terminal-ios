import Foundation
import Testing
@testable import DesignSystem

@Suite("TerminalTheme")
struct TerminalThemeTests {
    @Test("bundled themes include at least 5 named themes")
    func bundledThemesCount() {
        #expect(TerminalTheme.bundled.count >= 5)
    }

    @Test("every bundled theme has exactly 16 ANSI colors")
    func ansiColorCount() {
        for theme in TerminalTheme.bundled {
            #expect(theme.ansi.count == 16, "Theme \(theme.name) has \(theme.ansi.count) ANSI colors, expected 16")
        }
    }

    @Test("bundled themes have unique IDs")
    func uniqueIDs() {
        let ids = TerminalTheme.bundled.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("default theme is the first bundled theme")
    func defaultIsFirst() {
        #expect(TerminalTheme.default.id == TerminalTheme.bundled.first?.id)
    }

    @Test("theme round-trips through Codable")
    func codableRoundTrip() throws {
        let original = TerminalTheme.bundled.first!
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TerminalTheme.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.ansi.count == 16)
        #expect(decoded.foreground == original.foreground)
        #expect(decoded.background == original.background)
    }

    @Test("tokyoNight theme has expected name")
    func tokyoNightName() {
        let theme = TerminalTheme.bundled.first { $0.id == "tokyo-night" }
        #expect(theme != nil)
        #expect(theme?.name == "Tokyo Night")
    }
}
