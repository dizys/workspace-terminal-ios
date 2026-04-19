#if os(iOS) || os(visionOS)
@preconcurrency import SwiftTerm
import UIKit

struct TerminalColorSet {
    let foreground: UIColor
    let background: UIColor
    let cursor: UIColor
}

extension TerminalColorSet {
    func apply(to view: TerminalView) {
        // Only set fg/bg/cursor via UIKit properties. Do NOT feed OSC
        // escape sequences — SwiftTerm's internal TerminalDelegate
        // processes them and sends response bytes through the send path,
        // which the remote shell echoes as literal text garbage.
        //
        // The 16 ANSI colors use SwiftTerm's default xterm palette. Custom
        // ANSI palette support requires a SwiftTerm API fix (the public
        // installPalette/installColors signatures use an unqualified [Color]
        // that's ambiguous when SwiftUI is in scope). We'll revisit when
        // SwiftTerm addresses this.
        view.nativeForegroundColor = foreground
        view.nativeBackgroundColor = background
        view.backgroundColor = background
        view.caretColor = cursor
    }
}
#endif
