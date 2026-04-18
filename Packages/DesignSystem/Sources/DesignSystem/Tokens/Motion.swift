import SwiftUI

/// Spring presets. Use these instead of inventing animations per-call so the
/// app feels coherent.
public enum WTMotion {
    /// Snappy — for state toggles (button press, tab switch).
    public static let snap = Animation.spring(response: 0.3, dampingFraction: 0.86)
    /// Smooth — for screen / sheet transitions.
    public static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.85)
    /// Bouncy — for delightful confirmations (purchase complete, sign-in success).
    public static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.65)
    /// Linear — for progress indicators.
    public static let linear = Animation.linear(duration: 1)
}
