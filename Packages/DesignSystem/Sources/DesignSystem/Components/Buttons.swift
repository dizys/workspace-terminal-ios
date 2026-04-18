import SwiftUI

/// Primary call-to-action. Solid accent fill, large tap target.
public struct WTPrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    public init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: WTSpace.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(WTColor.textOnAccent)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(WTFont.bodyEmphasized)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(WTColor.textOnAccent)
            .background(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .fill(WTColor.accent)
            )
            .opacity(isLoading ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

/// Secondary button. Translucent surface with hairline border.
public struct WTSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: WTSpace.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(WTFont.bodyEmphasized)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(WTColor.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .fill(WTColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .strokeBorder(WTColor.border, lineWidth: WTStroke.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Branded OAuth / sign-in button — accent leading icon, descriptive label.
public struct WTOAuthButton: View {
    public enum Variant: Sendable {
        case github
        case oidc(displayText: String, iconURL: URL?)
        case password

        var systemIcon: String {
            switch self {
            case .github:   return "person.crop.square.filled.and.at.rectangle"
            case .oidc:     return "key.horizontal.fill"
            case .password: return "envelope.fill"
            }
        }

        var fillColor: Color {
            switch self {
            case .github:   return WTColor.adaptive(light: 0x000000, dark: 0xFFFFFF)
            case .oidc:     return WTColor.accent
            case .password: return WTColor.surfaceElevated
            }
        }

        var textColor: Color {
            switch self {
            case .github:   return WTColor.adaptive(light: 0xFFFFFF, dark: 0x000000)
            case .oidc:     return WTColor.textOnAccent
            case .password: return WTColor.textPrimary
            }
        }

        var label: String {
            switch self {
            case .github:                 return "Continue with GitHub"
            case let .oidc(text, _):      return text
            case .password:               return "Email & password"
            }
        }
    }

    let variant: Variant
    let action: () -> Void

    public init(variant: Variant, action: @escaping () -> Void) {
        self.variant = variant
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: WTSpace.md) {
                Image(systemName: variant.systemIcon)
                    .font(.system(size: 18, weight: .semibold))
                Text(variant.label)
                    .font(WTFont.bodyEmphasized)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, WTSpace.lg)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(variant.textColor)
            .background(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .fill(variant.fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WTRadius.md, style: .continuous)
                    .strokeBorder(WTColor.border.opacity(0.5), lineWidth: WTStroke.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}
