import Foundation

// MARK: - Rutina

struct Routine: Codable, Equatable {
    var profe: String
    var days: [RoutineDay]
}

struct RoutineDay: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var exercises: [RoutineExercise]
}

struct RoutineExercise: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var series: Int
    var reps: String
    /// Se hace con el peso del cuerpo (cuentan las reps). nil = se decide por el nombre.
    var bodyweight: Bool?
    /// Dibujo elegido a mano (id de `Motions`). nil = se elige solo por el nombre.
    var figure: String?

    /// Clave del historial: el nombre sin tildes ni mayúsculas.
    var key: String { exerciseKey(name) }

    var isBodyweight: Bool { bodyweight ?? looksBodyweight(name) }

    /// Reps objetivo de cada serie según la planilla ("12" → 12 en todas; "12-10-8" con 3 series → 12, 10, 8).
    var targetReps: [Int] {
        let numbers = reps.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        if numbers.count == series { return numbers }
        return Array(repeating: numbers.max() ?? 10, count: max(series, 1))
    }
}

/// Flexiones, fondos, dominadas y abdominales se hacen sin peso.
func looksBodyweight(_ name: String) -> Bool {
    let k = exerciseKey(name)
    return ["flexion", "fondo", "dominada", "abdominal", "crunch", "plancha", "burpee"].contains { k.contains($0) }
}

/// Puntaje de una serie: gana más peso y, con el mismo peso, más reps.
/// En los ejercicios sin peso el peso es 0, así que cuentan solo las reps.
struct SetScore: Comparable, Hashable {
    var weight: Double
    var reps: Int

    static func < (a: SetScore, b: SetScore) -> Bool {
        (a.weight, a.reps) < (b.weight, b.reps)
    }
}

// MARK: - Historial

/// Lo que se hizo de un ejercicio en una fecha.
struct HistoryEntry: Codable, Equatable {
    /// "yyyy-MM-dd" en hora local.
    var date: String
    var sets: [Double]
    var done: [Bool]
    /// Récord logrado ese día (la mejor serie que superó al histórico): peso y reps.
    var prW: Double?
    var prR: Int?
    /// Reps hechas en cada serie. nil en anotaciones viejas (se toman las de la planilla).
    var reps: [Int]?
    /// Día de la rutina en que se anotó. nil en los pesos de ejemplo.
    var day: String?
    /// Entrenamiento al que pertenece. nil si se anotó sin arrancar uno.
    var session: UUID?

    var hasDone: Bool { done.contains(true) }

    var doneIndices: [Int] { sets.indices.filter { $0 < done.count && done[$0] } }

    func repsAt(_ i: Int, fallback: [Int]) -> Int {
        if let reps, reps.indices.contains(i) { return reps[i] }
        if fallback.indices.contains(i) { return fallback[i] }
        return fallback.last ?? 0
    }
}

struct Session: Codable, Equatable {
    var dayIndex: Int
    var dayName: String
    var start: Date
    /// Fecha en la que se anotan las series de este entrenamiento.
    var date: String
    /// Ejercicio que se muestra en la pantalla de bloqueo.
    var currentKey: String?
    var confirmingEnd: Bool
    var lastActivity: Date?
    /// Cada entrenamiento es independiente: se pueden hacer varios el mismo día.
    var id: UUID?
    /// Dos ejercicios que se alternan serie por serie (solo en este entrenamiento).
    var superset: [String]?
}

struct BodyWeight: Codable, Equatable, Identifiable {
    var id = UUID()
    var date: Date
    var kg: Double
}

struct PRItem: Codable, Equatable, Hashable {
    var name: String
    var weight: Double
    var previous: Double
    /// "45 kg × 10" o "15 reps".
    var text: String?
    var previousText: String?
}

struct SessionLog: Codable, Equatable, Identifiable {
    var id = UUID()
    var dayName: String
    var start: Date
    var end: Date
    var exercisesDone: Int
    var exercisesTotal: Int
    var sets: Int
    /// Kilos totales: peso × repeticiones de cada serie hecha.
    var volume: Double
    var prs: [PRItem]

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

struct AppData: Codable {
    var routine: Routine
    /// Historial por nombre de ejercicio (clave de `exerciseKey`).
    var hist: [String: [HistoryEntry]]
    /// Todavía están los pesos de ejemplo.
    var demo: Bool
    /// Salto de peso de los botones + y −.
    var step: Double
    var session: Session?
    var log: [SessionLog]
    /// Resumen que falta mostrar (por ejemplo, si se terminó desde la pantalla de bloqueo).
    var pendingSummary: UUID?
    /// Peso corporal cargado a mano, del más viejo al más nuevo.
    var bodyWeights: [BodyWeight]?
    /// Nombre para el saludo del inicio.
    var userName: String?
    /// Entrenamientos por semana que querés hacer.
    var weeklyGoal: Int?
    /// Tema de colores (AppTheme).
    var theme: String?

    static func initial() -> AppData {
        AppData(
            routine: SampleData.routine,
            hist: SampleData.demoHistory(),
            demo: true,
            step: 2.5,
            session: nil,
            log: [],
            pendingSummary: nil
        )
    }
}

struct ExerciseStatus {
    var done: Int
    var all: Bool
    var record: SetScore?
}

struct ProgressPoint: Hashable {
    var date: String
    var weight: Double
}

// MARK: - Ayudas

func exerciseKey(_ name: String) -> String {
    name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        .lowercased()
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}

enum Dates {
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date = Date()) -> String { keyFormatter.string(from: date) }

    /// "2026-10-22" → "22/10"
    static func short(_ key: String) -> String {
        let p = key.split(separator: "-")
        return p.count == 3 ? "\(p[2])/\(p[1])" : key
    }

    static func short(_ date: Date) -> String { short(key(date)) }
}

/// 3725 s → "1:02:05"; 312 s → "5:12"
func formatElapsed(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

/// 3240 → "3.240"
func fmtThousands(_ value: Double) -> String {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "es_AR")
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: value.rounded())) ?? String(Int(value.rounded()))
}

/// "45 kg × 10" o, sin peso, "15 reps".
func scoreText(_ s: SetScore, bodyweight: Bool) -> String {
    bodyweight ? "\(s.reps) reps" : "\(fmtW(s.weight)) kg × \(s.reps)"
}

// MARK: - Datos de ejemplo: planilla de Roberto (Plantilla_Rutinas_PROFE.pdf)

enum SampleData {
    static let routine = Routine(profe: "Roberto", days: [
        day("Pecho y Bíceps", [
            ("Press plano barra", 3, "12"), ("Aperturas planas", 3, "12"), ("Flexiones de brazos", 4, "10"),
            ("Pullover con mancuerna", 3, "10"), ("Curl barra recta", 3, "12"), ("Banco Scott mancuerna", 3, "12"),
            ("Curl mancuernas alternado", 3, "12"), ("Curl concentrado", 4, "10"),
        ]),
        day("Piernas y Hombros", [
            ("Extensiones de cuádriceps", 4, "12"), ("Sentadilla libre", 3, "10"), ("Camilla femoral", 3, "12"),
            ("Peso muerto rumano", 3, "10"), ("Press militar barra", 3, "12"), ("Vuelos laterales mancuernas", 3, "12"),
            ("Vuelos frontales", 3, "12"), ("Posteriores en máquina", 3, "10"),
        ]),
        day("Espalda y Tríceps", [
            ("Jalón al pecho", 4, "12"), ("Remo sentado en polea", 3, "12"), ("Jalón agarre cerrado", 3, "12"),
            ("Remo con mancuerna a un brazo", 4, "10"), ("Fondos entre bancos", 3, "12"), ("Press francés barra W", 3, "10"),
            ("Extensión en polea barra", 4, "12"), ("Patada de tríceps", 3, "10"),
        ]),
    ])

    private static func day(_ name: String, _ list: [(String, Int, String)]) -> RoutineDay {
        RoutineDay(name: name, exercises: list.map { RoutineExercise(name: $0.0, series: $0.1, reps: $0.2) })
    }

    private static let demoWeights: [(String, Double)] = [
        ("press plano barra", 40), ("aperturas planas", 12), ("pullover con mancuerna", 16), ("curl barra recta", 25),
        ("banco scott mancuerna", 10), ("curl mancuernas alternado", 12), ("curl concentrado", 10),
        ("extensiones de cuadriceps", 45), ("sentadilla libre", 60), ("camilla femoral", 35), ("peso muerto rumano", 50),
        ("press militar barra", 30), ("vuelos laterales mancuernas", 8), ("vuelos frontales", 8), ("posteriores en maquina", 25),
        ("jalon al pecho", 50), ("remo sentado en polea", 45), ("jalon agarre cerrado", 45),
        ("remo con mancuerna a un brazo", 20), ("press frances barra w", 20), ("extension en polea barra", 25),
        ("patada de triceps", 7.5),
    ]

    /// 5 sesiones de ejemplo por ejercicio, subiendo de a poco hasta el peso de `demoWeights`.
    static func demoHistory(now: Date = Date()) -> [String: [HistoryEntry]] {
        let steps: [Double] = [-5, -5, -2.5, -2.5, 0]
        let back = [30, 23, 16, 9, 3]
        let all = routine.days.flatMap(\.exercises)
        var hist: [String: [HistoryEntry]] = [:]
        for (i, item) in demoWeights.enumerated() {
            let (k, w) = item
            let n = all.first { $0.key == k }?.series ?? 3
            let inc: Double = w < 15 ? (w < 9 ? 0.5 : 1) : 1
            hist[k] = back.enumerated().map { j, b in
                let extra = (j == 2 && i % 2 == 1) ? 1.25 * inc : 0
                let v = max(0, w + steps[j] * inc * (w < 15 ? 0.4 : 1) + extra)
                let rounded = (v * 2).rounded() / 2
                let date = Calendar.current.date(byAdding: .day, value: -(b + i % 3), to: now) ?? now
                return HistoryEntry(
                    date: Dates.key(date),
                    sets: Array(repeating: rounded, count: n),
                    done: Array(repeating: true, count: n)
                )
            }
        }
        return hist
    }
}
