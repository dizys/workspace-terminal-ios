import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Brand + semantic color tokens.
///
/// Dark-first palette: deep cool slate base, distinctive teal accent (`Brand.accent`),
/// semantic status colors that match the same teal/coral/amber/blue family.
/// Light mode is supported via SwiftUI's automatic adaptive `Color(light:dark:)`.
public enum WTColor {
    // MARK: - Brand

    public static let accent = adaptive(light: 0x16A99A, dark: 0x3DCFB6)
    public static let accentMuted = adaptive(light: 0x16A99A, dark: 0x2DA793).opacity(0.85)
    public static let accentSoft = adaptive(light: 0x16A99A, dark: 0x3DCFB6).opacity(0.12)

    // MARK: - Surfaces

    /// App canvas background.
    public static let background = adaptive(light: 0xFFFFFF, dark: 0x0A0E14)
    /// First-level surface (cards, list rows, sheets).
    public static let surface = adaptive(light: 0xF6F8FA, dark: 0x141921)
    /// Second-level surface (raised cards, popovers).
    public static let surfaceElevated = adaptive(light: 0xFFFFFF, dark: 0x1B2129)
    /// Subtle hairline border.
    public static let border = adaptive(light: 0xD0D7DE, dark: 0x2A323D)
    /// Stronger border for active/focused state.
    public static let borderStrong = adaptive(light: 0x8B949E, dark: 0x4A5563)

    // MARK: - Content

    public static let textPrimary = adaptive(light: 0x1F2328, dark: 0xE6EDF3)
    public static let textSecondary = adaptive(light: 0x59636E, dark: 0x9DA7B3)
    public static let textTertiary = adaptive(light: 0x848F99, dark: 0x6E7681)
    public static let textOnAccent = Color.white

    // MARK: - Status

    public static let statusRunning = adaptive(light: 0x1A7F37, dark: 0x5DD68F)
    public static let statusPending = adaptive(light: 0x0969DA, dark: 0x6FB7FF)
    public static let statusStopped = adaptive(light: 0x6E7681, dark: 0x8B949E)
    public static let statusWarning = adaptive(light: 0xBF8700, dark: 0xF2CC60)
    public static let statusError = adaptive(light: 0xCF222E, dark: 0xFB7D7D)

    // MARK: - Helpers

    /// Builds a Color that switches between two hex values for light/dark.
    public static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
        #else
        // macOS fallback — use the dark variant unconditionally; the package's
        // SwiftUI views are gated to iOS, so this only matters for tests.
        return Color(hexLiteral: dark)
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif

extension Color {
    fileprivate init(hexLiteral hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
