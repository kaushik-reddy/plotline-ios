import SwiftUI

/// Design tokens ported from the web app's `index.css` `:root` variables so the
/// iOS app matches the site pixel-for-pixel: pure-black canvas, orange accent,
/// and the shared status/semantic colors.
enum Theme {
    // Surfaces
    static let bg = Color(hex: 0x050505)
    static let panel = Color(hex: 0x0D0D0D)
    static let panelRaised = Color(hex: 0x121212)
    static let header = Color(hex: 0x050505)

    // Text
    static let text = Color(hex: 0xF5F5F4)
    static let muted = Color.white.opacity(0.45)
    static let faint = Color.white.opacity(0.28)

    // Lines
    static let line = Color.white.opacity(0.10)
    static let lineStrong = Color.white.opacity(0.18)

    // Accents / semantics
    static let orange = Color(hex: 0xF47421)
    static let green = Color(hex: 0x29C463)
    static let amber = Color(hex: 0xE0A33A)
    static let blue = Color(hex: 0x4F8CF7)
    static let red = Color(hex: 0xFF5A5A)
    static let teal = Color(hex: 0x2DD4BF)
    static let gold = Color(hex: 0xFFC043)

    static let radius: CGFloat = 6
    static let posterAspect: CGFloat = 2.0 / 3.0
}

extension Color {
    /// Create a Color from a 0xRRGGBB integer literal.
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Parse a "#RRGGBB" / "RRGGBB" hex string (used for TMDB/status colors coming
    /// from data). Falls back to muted gray on malformed input.
    init(css: String) {
        var s = css.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if let v = UInt32(s, radix: 16), s.count == 6 {
            self.init(hex: v)
        } else {
            self = Color.gray
        }
    }
}
