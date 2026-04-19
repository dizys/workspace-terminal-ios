#if os(iOS) || os(visionOS)
import DesignSystem
@preconcurrency import SwiftTerm
import UIKit

extension TerminalTheme {
    func apply(to view: TerminalView) {
        let terminal = view.getTerminal()

        let palette: [Attribute.Color] = ansi.map { hex in
            let (r, g, b) = hex.rgb
            return .trueColor(red: r, green: g, blue: b)
        }
        terminal.installPalette(colors: palette)

        view.nativeForegroundColor = foreground.uiColor
        view.nativeBackgroundColor = background.uiColor
        view.backgroundColor = background.uiColor
        view.caretColor = cursor.uiColor
    }
}
#endif
