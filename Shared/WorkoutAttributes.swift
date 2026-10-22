import ActivityKit
import SwiftUI

/// Datos de la Live Activity. Compartido entre la app y la extensión del widget.
struct WorkoutAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
    }

    var title: String
}

/// Paleta de la maqueta (gym.html).
enum Palette {
    static let bg = Color(red: 0x0f / 255, green: 0x11 / 255, blue: 0x0d / 255)
    static let surface = Color(red: 0x18 / 255, green: 0x1b / 255, blue: 0x15 / 255)
    static let surface2 = Color(red: 0x22 / 255, green: 0x26 / 255, blue: 0x1e / 255)
    static let line = Color(red: 0x2f / 255, green: 0x35 / 255, blue: 0x29 / 255)
    static let fg = Color(red: 0xee / 255, green: 0xf2 / 255, blue: 0xe6 / 255)
    static let muted = Color(red: 0x99 / 255, green: 0xa2 / 255, blue: 0x8c / 255)
    static let accent = Color(red: 0xc6 / 255, green: 0xf4 / 255, blue: 0x32 / 255)
    static let accentInk = Color(red: 0x14 / 255, green: 0x1a / 255, blue: 0x03 / 255)
    static let warn = Color(red: 0xf2 / 255, green: 0xb8 / 255, blue: 0x4b / 255)
}

extension Font {
    /// Tipografía condensada, equivalente a "Barlow Condensed" de la maqueta.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}
