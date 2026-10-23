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
        var doneExercises: Int
        var totalExercises: Int
        /// Se tocó "Terminar" y falta confirmar.
        var confirmingEnd: Bool
        /// Resumen final ("52:30 · 18 series · 3.240 kg") cuando ya terminó.
        var finishedSummary: String?
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
    static let gold = Color(red: 0xf5 / 255, green: 0xc5 / 255, blue: 0x42 / 255)
    static let warn = Color(red: 0xf2 / 255, green: 0xb8 / 255, blue: 0x4b / 255)
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
