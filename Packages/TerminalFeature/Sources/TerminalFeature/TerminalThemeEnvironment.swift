#if os(iOS)
import DesignSystem
import SwiftUI

private struct TerminalThemeKey: EnvironmentKey {
    static let defaultValue: TerminalTheme = .default
}

extension EnvironmentValues {
    public var terminalTheme: TerminalTheme {
        get { self[TerminalThemeKey.self] }
        set { self[TerminalThemeKey.self] = newValue }
    }
}
#endif
