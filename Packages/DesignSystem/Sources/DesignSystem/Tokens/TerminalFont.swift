#if canImport(UIKit)
import UIKit

/// Helpers for the bundled JetBrains Mono Nerd Font.
///
/// The font is registered via UIAppFonts in Info.plist. The family name
/// is "JetBrainsMono Nerd Font" (with space before "Nerd") per the
/// Nerd Fonts patching convention.
public enum WTFont_Terminal {
    public static let familyName = "JetBrainsMono Nerd Font"

    public static func regular(size: CGFloat) -> UIFont {
        UIFont(name: "JetBrainsMonoNerdFont-Regular", size: size)
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    public static func bold(size: CGFloat) -> UIFont {
        UIFont(name: "JetBrainsMonoNerdFont-Bold", size: size)
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    public static func italic(size: CGFloat) -> UIFont {
        UIFont(name: "JetBrainsMonoNerdFont-Italic", size: size)
            ?? regular(size: size)
    }

    public static func boldItalic(size: CGFloat) -> UIFont {
        UIFont(name: "JetBrainsMonoNerdFont-BoldItalic", size: size)
            ?? bold(size: size)
    }
}
#endif
