import SwiftUI

/// 4-pt spacing scale.
public enum WTSpace {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
    public static let xxxxl: CGFloat = 40
    public static let huge: CGFloat = 56
}

/// Border radius scale.
public enum WTRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let pill: CGFloat = 999
}

/// Hairline border width — uses 1pt at 1x, 0.5pt at 2x+ for crispness.
public enum WTStroke {
    public static let hairline: CGFloat = 1
    public static let medium: CGFloat = 1.5
    public static let strong: CGFloat = 2
}
