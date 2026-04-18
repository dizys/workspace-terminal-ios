import Foundation

/// JSON coders configured for Coder's wire format.
///
/// Coder uses RFC-3339 (ISO-8601) timestamps with fractional seconds and
/// optional timezone. These coders handle both with and without fractional
/// seconds for resilience.
public enum JSONCoders {
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = isoFormatterFractional.date(from: raw) {
                return date
            }
            if let date = isoFormatter.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(raw)"
            )
        }
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }

    // ISO8601DateFormatter is documented thread-safe for date(from:) once
    // configured. Sharing one instance avoids per-decode allocation cost.
    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated(unsafe) private static let isoFormatterFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
