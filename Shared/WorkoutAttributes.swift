import ActivityKit
import SwiftUI

/// Datos de la Live Activity. Compartido entre la app y la extensión del widget.
struct WorkoutAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var dayName: String
        /// Ejercicio actual; nil cuando ya están todos hechos.
        var exercise: String?
        var setNumber: Int
        var setCount: Int
        var reps: String
        var weight: Double
        /// La serie actual (peso y reps) supera la mejor histórica.
        var recordPace: Bool
        /// Reps de la serie actual.
        var setReps: Int
        /// Ejercicio sin peso: se muestran solo las reps.
        var bodyweight: Bool
        /// El ejercicio actual está en una superserie.
        var superset: Bool
        var doneExercises: Int
        var totalExercises: Int
        /// Se tocó "Terminar" y falta confirmar.
        var confirmingEnd: Bool
        /// Resumen final ("52:30 · 18 series · 3.240 kg") cuando ya terminó.
        var finishedSummary: String?
        /// Tema de colores elegido en la app (la extensión no puede leer los ajustes).
        var theme: String = AppTheme.lime.rawValue
    }

    var title: String
}

extension Color {
    /// Color desde un número hexadecimal: Color(hex: 0xC6F432).
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Temas de colores. Todos oscuros; cambia el acento y el tono del fondo.
enum AppTheme: String, CaseIterable, Identifiable {
    case lime, orange, ice, red, violet, mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lime: "Lima"
        case .orange: "Naranja fuego"
        case .ice: "Celeste hielo"
        case .red: "Rojo"
        case .violet: "Violeta neón"
        case .mono: "Blanco y negro"
        }
    }

    /// Nombre del ícono alternativo (nil = ícono principal).
    var iconName: String? {
        self == .lime ? nil : "AppIcon-\(rawValue)"
    }

    // bg, surface, surface2, line, muted, accent, accentInk
    var hexes: [UInt32] {
        switch self {
        case .lime: [0x0F110D, 0x181B15, 0x22261E, 0x2F3529, 0x99A28C, 0xC6F432, 0x141A03]
        case .orange: [0x120E0B, 0x1C1611, 0x261E17, 0x3A2D22, 0xA8988A, 0xFF6B1A, 0x1A0B02]
        case .ice: [0x0B1014, 0x121A20, 0x1A242C, 0x283642, 0x8C9CA8, 0x38D6FF, 0x02141A]
        case .red: [0x130C0D, 0x1D1314, 0x281B1C, 0x3D2829, 0xA8908F, 0xFF3B4E, 0x1A0306]
        case .violet: [0x0F0D14, 0x17141F, 0x201C2A, 0x312B40, 0x9C94AC, 0xA970FF, 0x12051F]
        case .mono: [0x0A0A0A, 0x151515, 0x1F1F1F, 0x2E2E2E, 0x9A9A9A, 0xF2F2F2, 0x0A0A0A]
        }
    }
}

/// Colores de la app según el tema elegido (por defecto, la paleta de la maqueta).
enum Palette {
    private static var theme = AppTheme.lime

    /// Cambia el tema activo. La app lo llama al arrancar y al elegir otro; la
    /// Live Activity, con el tema que viene en su estado.
    static func use(_ name: String?) {
        theme = name.flatMap(AppTheme.init(rawValue:)) ?? .lime
    }

    static var current: AppTheme { theme }

    static var bg: Color { Color(hex: theme.hexes[0]) }
    static var surface: Color { Color(hex: theme.hexes[1]) }
    static var surface2: Color { Color(hex: theme.hexes[2]) }
    static var line: Color { Color(hex: theme.hexes[3]) }
    static var muted: Color { Color(hex: theme.hexes[4]) }
    static var accent: Color { Color(hex: theme.hexes[5]) }
    static var accentInk: Color { Color(hex: theme.hexes[6]) }
    static var fg: Color { theme == .lime ? Color(hex: 0xEEF2E6) : Color(hex: 0xF1F1EE) }
    static let gold = Color(hex: 0xF5C542)
    static let warn = Color(hex: 0xF2B84B)
}

extension Font {
    /// Tipografía condensada, equivalente a "Barlow Condensed" de la maqueta.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

/// 42.5 → "42,5"; 40 → "40"
func fmtW(_ w: Double) -> String {
    let r = (w * 10).rounded() / 10
    if r == r.rounded() { return String(Int(r)) }
    return String(format: "%.1f", r).replacingOccurrences(of: ".", with: ",")
}
