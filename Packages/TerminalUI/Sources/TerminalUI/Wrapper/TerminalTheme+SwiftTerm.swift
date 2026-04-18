#if os(iOS) || os(visionOS)
import DesignSystem
import SwiftTerm
import UIKit

extension TerminalTheme {
    func apply(to view: TerminalView) {
        let ansiColors: [Attribute.Color] = ansi.map { hex in
            let (r, g, b) = hex.rgb
            return .trueColor(red: r, green: g, blue: b)
        }
        view.installColors(ansiColors)

        view.nativeForegroundColor = foreground.uiColor
        view.nativeBackgroundColor = background.uiColor
        view.backgroundColor = background.uiColor

        let (cr, cg, cb) = cursor.rgb
        view.setCursorColor(
            source: view.getTerminal(),
            color: .trueColor(red: cr, green: cg, blue: cb),
            textColor: nil
        )
    }
}
#endif
