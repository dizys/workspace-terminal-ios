import Foundation

/// A terminal color theme defining the 16 ANSI colors, foreground, background,
/// and cursor colors. Codable for custom-theme JSON import.
///
/// SwiftTerm's `installColors([Color])` takes an array of exactly 16 ANSI
/// colors (indices 0–7 normal, 8–15 bright). Foreground, background, and
/// cursor are set via separate properties on `TerminalView`.
public struct TerminalTheme: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let ansi: [HexColor]
    public let foreground: HexColor
    public let background: HexColor
    public let cursor: HexColor
    public let selectionBackground: HexColor

    public init(
        id: String,
        name: String,
        ansi: [HexColor],
        foreground: HexColor,
        background: HexColor,
        cursor: HexColor,
        selectionBackground: HexColor
    ) {
        precondition(ansi.count == 16, "TerminalTheme requires exactly 16 ANSI colors")
        self.id = id
        self.name = name
        self.ansi = ansi
        self.foreground = foreground
        self.background = background
        self.cursor = cursor
        self.selectionBackground = selectionBackground
    }

    public static let `default` = bundled[0]
}

/// A hex-encoded color (e.g. `"#c0caf5"`) that is Codable + Hashable.
/// Conversion to platform color types happens at the point of use.
public struct HexColor: Sendable, Hashable, Codable {
    public let hex: String

    public init(_ hex: String) {
        self.hex = hex.hasPrefix("#") ? hex : "#\(hex)"
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self.hex = raw.hasPrefix("#") ? raw : "#\(raw)"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    public var rgb: (r: UInt8, g: UInt8, b: UInt8) {
        let clean = hex.dropFirst()
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else {
            return (0, 0, 0)
        }
        return (
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        )
    }
}

#if canImport(UIKit)
import UIKit

extension HexColor {
    public var uiColor: UIColor {
        let (r, g, b) = rgb
        return UIColor(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}
#endif

// MARK: - Bundled themes

extension TerminalTheme {
    public static let bundled: [TerminalTheme] = [
        .system,
        .tokyoNight,
        .catppuccinMocha,
        .solarizedDark,
        .dracula,
        .gruvboxDark,
    ]

    public static let system = TerminalTheme(
        id: "system",
        name: "System",
        ansi: [
            "#0A0E14", "#FF6B6B", "#3DCFB6", "#E6B450",
            "#5CCFE6", "#D4BFFF", "#95E6CB", "#E6EDF3",
            "#2A323D", "#FF8F8F", "#5EECC0", "#FFD580",
            "#73D0FF", "#E6CCFF", "#A8F0D8", "#F0F6FC",
        ].map(HexColor.init),
        foreground: HexColor("#E6EDF3"),
        background: HexColor("#0A0E14"),
        cursor: HexColor("#3DCFB6"),
        selectionBackground: HexColor("#1B2129")
    )

    public static let tokyoNight = TerminalTheme(
        id: "tokyo-night",
        name: "Tokyo Night",
        ansi: [
            "#15161e", "#f7768e", "#9ece6a", "#e0af68",
            "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6",
            "#414868", "#f7768e", "#9ece6a", "#e0af68",
            "#7aa2f7", "#bb9af7", "#7dcfff", "#c0caf5",
        ].map(HexColor.init),
        foreground: HexColor("#c0caf5"),
        background: HexColor("#1a1b26"),
        cursor: HexColor("#c0caf5"),
        selectionBackground: HexColor("#283457")
    )

    public static let catppuccinMocha = TerminalTheme(
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        ansi: [
            "#45475a", "#f38ba8", "#a6e3a1", "#f9e2af",
            "#89b4fa", "#f5c2e7", "#94e2d5", "#bac2de",
            "#585b70", "#f38ba8", "#a6e3a1", "#f9e2af",
            "#89b4fa", "#f5c2e7", "#94e2d5", "#a6adc8",
        ].map(HexColor.init),
        foreground: HexColor("#cdd6f4"),
        background: HexColor("#1e1e2e"),
        cursor: HexColor("#f5e0dc"),
        selectionBackground: HexColor("#45475a")
    )

    public static let solarizedDark = TerminalTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        ansi: [
            "#073642", "#dc322f", "#859900", "#b58900",
            "#268bd2", "#d33682", "#2aa198", "#eee8d5",
            "#002b36", "#cb4b16", "#586e75", "#657b83",
            "#839496", "#6c71c4", "#93a1a1", "#fdf6e3",
        ].map(HexColor.init),
        foreground: HexColor("#839496"),
        background: HexColor("#002b36"),
        cursor: HexColor("#839496"),
        selectionBackground: HexColor("#073642")
    )

    public static let dracula = TerminalTheme(
        id: "dracula",
        name: "Dracula",
        ansi: [
            "#21222c", "#ff5555", "#50fa7b", "#f1fa8c",
            "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2",
            "#6272a4", "#ff6e6e", "#69ff94", "#ffffa5",
            "#d6acff", "#ff92df", "#a4ffff", "#ffffff",
        ].map(HexColor.init),
        foreground: HexColor("#f8f8f2"),
        background: HexColor("#282a36"),
        cursor: HexColor("#f8f8f2"),
        selectionBackground: HexColor("#44475a")
    )

    public static let gruvboxDark = TerminalTheme(
        id: "gruvbox-dark",
        name: "Gruvbox Dark",
        ansi: [
            "#282828", "#cc241d", "#98971a", "#d79921",
            "#458588", "#b16286", "#689d6a", "#a89984",
            "#928374", "#fb4934", "#b8bb26", "#fabd2f",
            "#83a598", "#d3869b", "#8ec07c", "#ebdbb2",
        ].map(HexColor.init),
        foreground: HexColor("#ebdbb2"),
        background: HexColor("#282828"),
        cursor: HexColor("#ebdbb2"),
        selectionBackground: HexColor("#3c3836")
    )
}
