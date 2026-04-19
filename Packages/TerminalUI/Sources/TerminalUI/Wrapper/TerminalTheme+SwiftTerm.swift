#if os(iOS) || os(visionOS)
import DesignSystem
import SwiftTerm
import UIKit

extension TerminalTheme {
    func apply(to view: TerminalView) {
        let colorSet = TerminalColorSet(
            ansiRGB: ansi.map(\.rgb),
            foreground: foreground.uiColor,
            background: background.uiColor,
            cursor: cursor.uiColor
        )
        colorSet.apply(to: view)
    }
}
#endif
