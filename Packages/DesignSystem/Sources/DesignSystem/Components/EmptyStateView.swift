import SwiftUI

/// Branded empty-state view. Illustrated SF Symbol with accent ring,
/// title, description, optional action.
public struct WTEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: WTSpace.lg) {
            ZStack {
                Circle()
                    .fill(WTColor.accentSoft)
                    .frame(width: 88, height: 88)
                Circle()
                    .strokeBorder(WTColor.accent.opacity(0.3), lineWidth: WTStroke.hairline)
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(WTColor.accent)
            }

            VStack(spacing: WTSpace.sm) {
                Text(title)
                    .font(WTFont.headline)
                    .foregroundStyle(WTColor.textPrimary)
                Text(message)
                    .font(WTFont.subheadline)
                    .foregroundStyle(WTColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if let actionTitle, let action {
                WTPrimaryButton(actionTitle, action: action)
                    .frame(maxWidth: 280)
                    .padding(.top, WTSpace.sm)
            }
        }
        .padding(WTSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
