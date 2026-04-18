import SwiftUI

/// Typography scale. Use semantic names — never hard-code `.font(.system(...))`
/// in feature code so we can evolve the type system in one place.
public enum WTFont {
    public static let display = Font.system(size: 32, weight: .bold, design: .default)
    public static let title = Font.system(size: 24, weight: .semibold, design: .default)
    public static let titleEmphasized = Font.system(size: 24, weight: .bold, design: .default)
    public static let headline = Font.system(size: 18, weight: .semibold, design: .default)
    public static let body = Font.system(size: 16, weight: .regular, design: .default)
    public static let bodyEmphasized = Font.system(size: 16, weight: .semibold, design: .default)
    public static let subheadline = Font.system(size: 14, weight: .regular, design: .default)
    public static let subheadlineEmphasized = Font.system(size: 14, weight: .semibold, design: .default)
    public static let caption = Font.system(size: 12, weight: .medium, design: .default)
    public static let captionEmphasized = Font.system(size: 12, weight: .semibold, design: .default)

    /// SF Mono — for IDs, tokens, terminal text, code.
    public static let monoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    public static let monoBody = Font.system(size: 14, weight: .regular, design: .monospaced)
}
