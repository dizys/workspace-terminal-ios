import SwiftUI

/// A polished loader — concentric rotating arcs over the brand accent.
/// Use during meaningful waits (probing a deployment, signing in).
public struct WTCinematicLoader: View {
    let label: String?
    @State private var rotation: Double = 0

    public init(label: String? = nil) {
        self.label = label
    }

    public var body: some View {
        VStack(spacing: WTSpace.lg) {
            ZStack {
                Circle()
                    .strokeBorder(WTColor.accent.opacity(0.15), lineWidth: 3)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: 0.18)
                    .stroke(WTColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(rotation))
                Circle()
                    .trim(from: 0.55, to: 0.65)
                    .stroke(WTColor.accent.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-rotation * 1.5))
            }
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            if let label {
                Text(label)
                    .font(WTFont.subheadline)
                    .foregroundStyle(WTColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
