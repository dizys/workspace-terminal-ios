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
        let terminal = view.getTerminal()

        // Set the 16 ANSI colors via OSC 4 escape sequences. This is safe
        // because forwardSend is gated with a 500ms suppress window that
        // absorbs all DA1/DA2 responses AND any OSC response bytes.
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
