import Foundation

/// A Coder session token has the exact shape `<10-char-id>-<22-char-secret>`,
/// both halves alphanumeric. Coder's server validates these lengths
/// strictly — a 13-char id, for example, is rejected with "invalid API
/// key ID length, expected 10".
public enum CoderTokenFormat {
    /// Strict pattern matching Coder's own validation. Anchored to the
    /// whole string so substring matches don't leak through.
    public static let pattern = #"^[A-Za-z0-9]{10}-[A-Za-z0-9]{22}$"#

    public static func isValid(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
