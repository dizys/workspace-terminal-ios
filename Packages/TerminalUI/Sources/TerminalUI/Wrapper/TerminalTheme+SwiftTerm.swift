#if os(iOS) || os(visionOS)
import DesignSystem
@preconcurrency import SwiftTerm
import UIKit

extension TerminalTheme {
    func apply(to view: TerminalView) {
        let palette: [SwiftTerm.Attribute.Color] = ansi.map { hex in
            let (r, g, b) = hex.rgb
            return .trueColor(red: r, green: g, blue: b)
        }
        view.installColors(palette)

        view.nativeForegroundColor = foreground.uiColor
        view.nativeBackgroundColor = background.uiColor
        view.backgroundColor = background.uiColor

        let (cr, cg, cb) = cursor.rgb
        let cursorColor: SwiftTerm.Attribute.Color = .trueColor(red: cr, green: cg, blue: cb)
        view.setCursorColor(
            source: view.getTerminal(),
            color: cursorColor,
            textColor: nil
        )
    }
}
#endif
