import SwiftUI

/// Shared design primitives: colors, typography, themes, layout helpers.
public enum DesignSystem {}

public struct TerminalTheme: Sendable, Hashable, Identifiable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    public static let system = TerminalTheme(id: "system", displayName: "System")
    public static let tokyoNight = TerminalTheme(id: "tokyo-night", displayName: "Tokyo Night")
    public static let catppuccinMocha = TerminalTheme(id: "catppuccin-mocha", displayName: "Catppuccin Mocha")
    public static let solarizedDark = TerminalTheme(id: "solarized-dark", displayName: "Solarized Dark")
    public static let dracula = TerminalTheme(id: "dracula", displayName: "Dracula")
    public static let gruvbox = TerminalTheme(id: "gruvbox", displayName: "Gruvbox")

    public static let bundled: [TerminalTheme] = [
        .system, .tokyoNight, .catppuccinMocha, .solarizedDark, .dracula, .gruvbox,
    ]
}
