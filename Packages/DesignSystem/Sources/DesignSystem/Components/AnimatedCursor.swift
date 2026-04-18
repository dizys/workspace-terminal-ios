import SwiftUI

/// A blinking terminal cursor — 2pt-wide vertical bar in the brand accent.
/// Use as a decorative accent on hero areas to reinforce the terminal theme.
public struct WTAnimatedCursor: View {
    let height: CGFloat
    @State private var visible = true

    public init(height: CGFloat = 28) {
        self.height = height
    }

    public var body: some View {
        Rectangle()
            .fill(WTColor.accent)
            .frame(width: 3, height: height)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
