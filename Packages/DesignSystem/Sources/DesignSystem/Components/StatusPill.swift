import SwiftUI

/// A status indicator. Renders as a colored dot + label inside a softly tinted
/// pill. The dot pulses while in a transitional state.
public struct WTStatusPill: View {
    public enum Tone: Sendable, Equatable {
        case running
        case pending
        case stopped
        case warning
        case error
        case neutral

        var color: Color {
            switch self {
            case .running: return WTColor.statusRunning
            case .pending: return WTColor.statusPending
            case .stopped: return WTColor.statusStopped
            case .warning: return WTColor.statusWarning
            case .error:   return WTColor.statusError
            case .neutral: return WTColor.textTertiary
            }
        }

        var pulses: Bool {
            self == .pending
        }
    }

    let label: String
    let tone: Tone
    @State private var pulsePhase: CGFloat = 0

    public init(label: String, tone: Tone) {
        self.label = label
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: WTSpace.xs + 2) {
            ZStack {
                if tone.pulses {
                    Circle()
                        .fill(tone.color.opacity(0.25))
                        .frame(width: 16, height: 16)
                        .scaleEffect(0.5 + pulsePhase * 0.7)
                        .opacity(1.0 - pulsePhase)
                }
                Circle()
                    .fill(tone.color)
                    .frame(width: 8, height: 8)
            }
            Text(label)
                .font(WTFont.captionEmphasized)
                .foregroundStyle(tone.color)
        }
        .padding(.horizontal, WTSpace.md)
        .padding(.vertical, WTSpace.xs + 2)
        .background(
            Capsule(style: .continuous)
                .fill(tone.color.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tone.color.opacity(0.25), lineWidth: WTStroke.hairline)
        )
        .onAppear {
            guard tone.pulses else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulsePhase = 1
            }
        }
    }
}

/// Just the dot — for compact contexts (list rows).
public struct WTStatusDot: View {
    let tone: WTStatusPill.Tone
    @State private var pulsePhase: CGFloat = 0

    public init(tone: WTStatusPill.Tone) {
        self.tone = tone
    }

    public var body: some View {
        ZStack {
            if tone.pulses {
                Circle()
                    .fill(tone.color.opacity(0.3))
                    .frame(width: 22, height: 22)
                    .scaleEffect(0.5 + pulsePhase * 0.8)
                    .opacity(1.0 - pulsePhase)
            }
            Circle()
                .fill(tone.color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .strokeBorder(tone.color.opacity(0.4), lineWidth: 4)
                )
        }
        .frame(width: 22, height: 22)
        .onAppear {
            guard tone.pulses else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulsePhase = 1
            }
        }
    }
}
