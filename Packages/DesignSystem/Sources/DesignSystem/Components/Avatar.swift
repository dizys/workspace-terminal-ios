import SwiftUI

/// Circular avatar derived from a username (or arbitrary string). Renders
/// initials over a deterministic gradient — distinct color per name.
public struct WTAvatar: View {
    let name: String
    let size: CGFloat

    public init(name: String, size: CGFloat = 32) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        let initials = WTAvatar.initials(from: name)
        let gradient = WTAvatar.gradient(for: name)
        ZStack {
            Circle().fill(gradient)
            Text(initials)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
        }
        .frame(width: size, height: size)
    }

    static func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "?" }
        let parts = trimmed.split(separator: " ").prefix(2)
        if parts.count == 2 {
            return parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    static func gradient(for name: String) -> LinearGradient {
        let palettes: [(start: UInt32, end: UInt32)] = [
            (0x3DCFB6, 0x2A9789), // teal
            (0x6FB7FF, 0x3B82F6), // blue
            (0xC084FC, 0x7C3AED), // violet
            (0xF472B6, 0xDB2777), // pink
            (0xFB923C, 0xEA580C), // orange
            (0x5DD68F, 0x16A34A), // green
            (0xFCD34D, 0xEAB308), // yellow
        ]
        var hash: UInt32 = 5381
        for byte in name.utf8 { hash = (hash << 5) &+ hash &+ UInt32(byte) }
        let pair = palettes[Int(hash % UInt32(palettes.count))]
        return LinearGradient(
            colors: [Color(hex: pair.start), Color(hex: pair.end)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
