#if os(iOS) || os(visionOS)
import DesignSystem
import SwiftTerm
import UIKit

extension TerminalTheme {
    func apply(to view: TerminalView) {
        // SwiftTerm.Attribute.Color — not SwiftUI.Color
        typealias TermColor = Attribute.Color

        let palette: [TermColor] = ansi.map { hex in
            let (r, g, b) = hex.rgb
            return TermColor.trueColor(red: r, green: g, blue: b)
        }
        view.installColors(palette)

        view.nativeForegroundColor = foreground.uiColor
        view.nativeBackgroundColor = background.uiColor
        view.backgroundColor = background.uiColor

        let (cr, cg, cb) = cursor.rgb
        let cursorColor: TermColor = .trueColor(red: cr, green: cg, blue: cb)
        view.setCursorColor(
            source: view.getTerminal(),
            color: cursorColor,
            textColor: nil
        )
    }
}
#endif
