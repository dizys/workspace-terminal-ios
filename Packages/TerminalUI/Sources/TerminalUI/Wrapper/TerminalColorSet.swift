#if os(iOS) || os(visionOS)
@preconcurrency import SwiftTerm
import UIKit

struct TerminalColorSet {
    let ansiRGB: [(r: UInt8, g: UInt8, b: UInt8)]
    let foreground: UIColor
    let background: UIColor
    let cursor: UIColor
}

extension TerminalColorSet {
    func apply(to view: TerminalView) {
        // SwiftTerm's installPalette/installColors use unqualified `[Color]`
        // in their public signature. SwiftTerm itself imports SwiftUI, so
        // `Color` is ambiguous (Attribute.Color vs SwiftUI.Color) and cannot
        // be resolved from any external call site. Every attempt to pass
        // `[Attribute.Color]` fails with a type mismatch.
        //
        // Workaround: feed OSC 4 escape sequences directly into the terminal
        // emulator. This is exactly how a remote application (e.g. base16-shell)
        // sets ANSI colors — the terminal interprets them natively.
        //
        // OSC 4 ; <index> ; rgb:<rr>/<gg>/<bb> ST
        let terminal = view.getTerminal()
        for (i, rgb) in ansiRGB.prefix(16).enumerated() {
            let seq = "\u{1b}]4;\(i);rgb:\(hex2(rgb.r))/\(hex2(rgb.g))/\(hex2(rgb.b))\u{1b}\\"
            terminal.feed(text: seq)
        }

        // OSC 10 = foreground, OSC 11 = background, OSC 12 = cursor
        func osc(_ code: Int, _ color: UIColor) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            let seq = "\u{1b}]\(code);rgb:\(hex2f(r))/\(hex2f(g))/\(hex2f(b))\u{1b}\\"
            terminal.feed(text: seq)
        }
        osc(10, foreground)
        osc(11, background)
        osc(12, cursor)

        // Also set the UIKit-level properties so the view's own drawing
        // (selection, caret, empty-area fill) matches.
        view.nativeForegroundColor = foreground
        view.nativeBackgroundColor = background
        view.backgroundColor = background
        view.caretColor = cursor
    }
}

private func hex2(_ v: UInt8) -> String {
    String(format: "%02x", v)
}

private func hex2f(_ v: CGFloat) -> String {
    String(format: "%02x", Int(v * 255))
}
#endif
