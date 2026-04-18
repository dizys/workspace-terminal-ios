import SwiftUI

/// Card surface — a rounded, subtly bordered container with an elevated
/// background. Use for grouped content (workspace rows, info panels).
public struct WTCard<Content: View>: View {
    let content: () -> Content
    let padding: CGFloat
    let radius: CGFloat
    let elevated: Bool

    public init(
        padding: CGFloat = WTSpace.lg,
        radius: CGFloat = WTRadius.lg,
        elevated: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.padding = padding
        self.radius = radius
        self.elevated = elevated
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(elevated ? WTColor.surfaceElevated : WTColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(WTColor.border, lineWidth: WTStroke.hairline)
            )
    }
}

/// Card with a subtle accent gradient — used for hero / status sections.
public struct WTHeroCard<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .padding(WTSpace.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WTRadius.xl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WTColor.surfaceElevated,
                                WTColor.surface,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: WTRadius.xl, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                WTColor.accent.opacity(0.4),
                                WTColor.border,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: WTStroke.hairline
                    )
            )
    }
}
