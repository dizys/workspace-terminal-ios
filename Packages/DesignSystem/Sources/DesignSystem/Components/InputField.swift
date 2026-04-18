import SwiftUI

/// A polished input field — leading icon + label + hairline border + focus ring.
public struct WTInputField: View {
    let label: String?
    let placeholder: String
    let icon: String?
    let isSecure: Bool
    @Binding var text: String
    @FocusState private var focused: Bool

    public init(
        label: String? = nil,
        placeholder: String,
        icon: String? = nil,
        isSecure: Bool = false,
        text: Binding<String>
    ) {
        self.label = label
        self.placeholder = placeholder
        self.icon = icon
        self.isSecure = isSecure
        self._text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: WTSpace.sm) {
            if let label {
                Text(label)
                    .font(WTFont.captionEmphasized)
                    .foregroundStyle(WTColor.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            HStack(spacing: WTSpace.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(focused ? WTColor.accent : WTColor.textTertiary)
                        .frame(width: 20)
                        .animation(WTMotion.snap, value: focused)
                }
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(WTFont.body)
                .foregroundStyle(WTColor.textPrimary)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .focused($focused)
            }
            .padding(.horizontal, WTSpace.lg)
            .padding(.vertical, WTSpace.md + 2)
            .background(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .fill(WTColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .strokeBorder(
                        focused ? WTColor.accent.opacity(0.6) : WTColor.border,
                        lineWidth: focused ? WTStroke.medium : WTStroke.hairline
                    )
                    .animation(WTMotion.snap, value: focused)
            )
        }
    }
}
