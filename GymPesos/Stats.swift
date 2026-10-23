import Foundation

/// Cálculos para el inicio y la pestaña Progreso.
extension Store {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // la semana arranca el lunes
        c.locale = Locale(identifier: "es_AR")
        c.timeZone = .current
        return c
    }

    var weeklyGoal: Int { data.weeklyGoal ?? 3 }

    /// El día que hace más tiempo que no hacés (los que nunca hiciste van primero).
    var suggestedDayIndex: Int? {
        let days = routine.days
        guard !days.isEmpty else { return nil }
        return days.indices.min { (lastDate(of: days[$0]) ?? "") < (lastDate(of: days[$1]) ?? "") }
    }

    /// Fechas (yyyy-MM-dd) en las que entrenaste dentro de un período.
    func trainedDates(in interval: DateInterval) -> Set<String> {
        Set(data.log.filter { interval.contains($0.start) }.map { Dates.key($0.start) })
    }

    struct WeekInfo {
        var done: Int
        var goal: Int
        /// Semanas seguidas cumpliendo el objetivo (contando esta si ya se cumplió).
        var streak: Int
    }

    func weekInfo(now: Date = Date()) -> WeekInfo {
        let cal = Store.calendar
        let goal = weeklyGoal
        guard let week = cal.dateInterval(of: .weekOfYear, for: now) else { return WeekInfo(done: 0, goal: goal, streak: 0) }
        let done = trainedDates(in: week).count
        var streak = done >= goal ? 1 : 0
        var start = week.start
        for _ in 0..<520 {
            guard let before = cal.date(byAdding: .day, value: -1, to: start),
                  let prev = cal.dateInterval(of: .weekOfYear, for: before),
                  trainedDates(in: prev).count >= goal else { break }
            streak += 1
            start = prev.start
        }
        return WeekInfo(done: done, goal: goal, streak: streak)
    }

    struct NearRecord {
        var name: String
        var dayIndex: Int
        var text: String
        var record: String
    }

    /// En el día sugerido, el ejercicio en el que estás más cerca de tu récord.
    func nearRecord() -> NearRecord? {
        guard let d = suggestedDayIndex else { return nil }
        let day = routine.days[d]
        var best: (gap: Double, item: NearRecord)?
        var atRecord: NearRecord?
        for ex in day.exercises {
            let list = entries(ex.key).filter(\.hasDone)
            guard let last = list.last, let lastScore = bestDone(last, ex),
                  let rec = list.compactMap({ bestDone($0, ex) }).max() else { continue }
            let recText = scoreText(rec, bodyweight: ex.isBodyweight)
            if lastScore >= rec {
                if atRecord == nil {
                    atRecord = NearRecord(name: ex.name, dayIndex: d, text: "Estás en tu récord: probá superarlo", record: recText)
                }
                continue
            }
            let gap: Double
            let text: String
            if ex.isBodyweight || lastScore.weight == rec.weight {
                let n = rec.reps - lastScore.reps
                gap = Double(n) * 0.5
                text = "Te falta\(n == 1 ? "" : "n") \(n) rep\(n == 1 ? "" : "s")"
            } else {
                let w = rec.weight - lastScore.weight
                gap = w
                text = "Te faltan \(fmtW(w)) kg"
            }
            let item = NearRecord(name: ex.name, dayIndex: d, text: text, record: recText)
            if best == nil || gap < best!.gap { best = (gap, item) }
        }
        return best?.item ?? atRecord
    }

    /// El último récord que hiciste.
    func lastRecord() -> (pr: PRItem, date: Date)? {
        for l in data.log.reversed() {
            if let p = l.prs.first { return (p, l.end) }
        }
        return nil
    }

    struct MonthStats {
        var interval: DateInterval
        var logs: [SessionLog]
        var days: Int
        var volume: Double
        var records: Int
    }

    /// Resumen de un mes: 0 = este mes, −1 = el anterior, etc.
    func monthStats(offset: Int, now: Date = Date()) -> MonthStats? {
        let cal = Store.calendar
        guard let ref = cal.date(byAdding: .month, value: offset, to: now),
              let interval = cal.dateInterval(of: .month, for: ref) else { return nil }
        let logs = data.log.filter { interval.contains($0.start) }
        return MonthStats(
            interval: interval,
            logs: logs,
            days: Set(logs.map { Dates.key($0.start) }).count,
            volume: logs.reduce(0) { $0 + $1.volume },
            records: logs.reduce(0) { $0 + $1.prs.count }
        )
    }
}

/// "hoy", "ayer", "hace 3 días"
func relativeDay(_ date: Date, now: Date = Date()) -> String {
    let cal = Store.calendar
    let n = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
    switch n {
    case ..<1: return "hoy"
    case 1: return "ayer"
    default: return "hace \(n) días"
    }
}

/// 0.7666 → "0,77"
func fmtRatio(_ r: Double) -> String {
    String(format: "%.2f", r).replacingOccurrences(of: ".", with: ",")
}

enum SpanishDate {
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    private static let weekdayDay = formatter("EEEE d")
    private static let monthYear = formatter("LLLL yyyy")

    /// "jueves 23"
    static func weekdayAndDay(_ d: Date) -> String { weekdayDay.string(from: d) }
    /// "octubre 2026"
    static func monthAndYear(_ d: Date) -> String { monthYear.string(from: d) }
}
