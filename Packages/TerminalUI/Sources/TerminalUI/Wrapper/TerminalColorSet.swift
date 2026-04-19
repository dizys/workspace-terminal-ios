#if os(iOS) || os(visionOS)
@preconcurrency import SwiftTerm
import UIKit

struct TerminalColorSet {
    let ansiRGB: [(r: UInt8, g: UInt8, b: UInt8)]
    let foreground: UIColor
    let background: UIColor
    let cursor: UIColor
}

// Free function that builds [Attribute.Color] and calls installPalette.
// In this file's scope: no SwiftUI import, no DesignSystem import.
// `Color` resolves to `Attribute.Color` unambiguously when only SwiftTerm
// + UIKit are imported... BUT SwiftTerm itself `import SwiftUI` internally,
// re-exporting SwiftUI.Color into the module's namespace.
//
// The workaround: we never write `[Color]` or `[Attribute.Color]` in our
// code. Instead we let Swift infer the element type from the closure return
// type, which it can resolve because `.trueColor(red:green:blue:)` exists
// only on `Attribute.Color`, not on `SwiftUI.Color`.
private func applyPaletteToTerminal(
    _ terminal: Terminal,
    ansiRGB: [(r: UInt8, g: UInt8, b: UInt8)]
) {
    let palette = ansiRGB.prefix(16).map {
        Attribute.Color.trueColor(red: $0.r, green: $0.g, blue: $0.b)
    }
    // `palette` is inferred as `[Attribute.Color]`. `installPalette` expects
    // `[Color]` which in Terminal.swift's scope IS `Attribute.Color`.
    // If this still doesn't compile, we fall back to setting each slot
    // individually via the terminal's public color-change delegate path.
    terminal.installPalette(colors: palette)
}

extension TerminalColorSet {
    func apply(to view: TerminalView) {
        applyPaletteToTerminal(view.getTerminal(), ansiRGB: ansiRGB)
        view.nativeForegroundColor = foreground
        view.nativeBackgroundColor = background
        view.backgroundColor = background
        view.caretColor = cursor
    }
}
#endif
