import DesignSystem
import SwiftUI

/// SwiftTerm wrapper, floating key bar, gesture handlers.
///
/// Real SwiftTerm integration arrives in M2. M0 ships the placeholder so the
/// dependency graph compiles end-to-end.
public enum TerminalUI {}

public struct KeyBarConfig: Sendable, Hashable {
    public let topRow: [String]
    public let modifiers: [String]

    public init(topRow: [String], modifiers: [String]) {
        self.topRow = topRow
        self.modifiers = modifiers
    }

    public static let `default` = KeyBarConfig(
        topRow: ["esc", "tab", "~", "/", "|", "-", "↑", "↓", "←", "→"],
        modifiers: ["ctrl", "alt", "shift", "meta"]
    )
}
