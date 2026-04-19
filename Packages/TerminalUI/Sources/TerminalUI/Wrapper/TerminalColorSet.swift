#if os(iOS) || os(visionOS)
// This file intentionally does NOT import DesignSystem (which pulls in SwiftUI),
// because SwiftTerm's API uses unqualified `Color` which collides with
// SwiftUI.Color. Instead we accept raw (r,g,b) tuples and UIColor values.
@preconcurrency import SwiftTerm
import UIKit

struct TerminalColorSet {
    let ansiRGB: [(r: UInt8, g: UInt8, b: UInt8)]  // exactly 16
    let foreground: UIColor
    let background: UIColor
    let cursor: UIColor
}

extension TerminalColorSet {
    func apply(to view: TerminalView) {
        let terminal = view.getTerminal()

        let palette: [Attribute.Color] = ansiRGB.map {
            .trueColor(red: $0.r, green: $0.g, blue: $0.b)
        }
        terminal.installPalette(colors: palette)

        view.nativeForegroundColor = foreground
        view.nativeBackgroundColor = background
        view.backgroundColor = background
        view.caretColor = cursor
    }
}
#endif
