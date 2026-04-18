import Foundation

/// Defensive URL decoding for fields the Coder API can return as empty
/// strings (`""`) instead of omitting the key.
///
/// Foundation's `URL(string: "")` returns nil and `Codable`'s synthesized
/// URL decoding throws `.dataCorrupted` for empty/malformed strings —
/// which fails the entire response. This helper degrades gracefully:
/// missing key → nil, present empty string → nil, malformed string → nil,
/// only valid URL strings produce a non-nil URL.
public enum LenientURL {
    public static func decode<Container: KeyedDecodingContainerProtocol>(
        from container: Container,
        forKey key: Container.Key
    ) throws -> URL? {
        guard let raw = try container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return URL(string: trimmed)
    }
}
