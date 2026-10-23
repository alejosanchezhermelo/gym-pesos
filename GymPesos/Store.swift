import ActivityKit
import Foundation
import Observation
import UIKit

struct Celebration: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let weight: Double
    let previous: Double
}

/// Todo el estado de la app. Lo usan las pantallas y también los botones de la
/// Live Activity, que iOS ejecuta dentro de la app aunque esté cerrada.
@MainActor
@Observable
final class Store {
    static let shared = Store()

    private(set) var data: AppData
    private(set) var celebration: Celebration?

    private let fileURL: URL
    @ObservationIgnored private var liveChain: Task<Void, Never>?
    @ObservationIgnored private var notificationTasks: [Task<Void, Never>] = []

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("gympesos.json")
        fileURL = url
        data = Store.load(from: url, backupDir: dir)
    }

    private static func load(from url: URL, backupDir: URL) -> AppData {
        guard let raw = try? Data(contentsOf: url) else { return .initial() }
        if let decoded = try? JSONDecoder().decode(AppData.self, from: raw) { return decoded }
        // Si no se puede leer, no se pisa: queda guardado aparte.
        let backup = backupDir.appendingPathComponent("gympesos-backup-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: backup)
        return .initial()
    }

    private func save() {
        do {
            let raw = try JSONEncoder().encode(data)
            try raw.write(to: fileURL, options: .atomic)
        } catch {
            print("No se pudo guardar: \(error)")
        }
    }

    // MARK: - Consultas

    var routine: Routine { data.routine }
    var session: Session? { data.session }

    /// Fecha en la que se anotan las series: la del entrenamiento en curso, o hoy.
    var workDate: String { data.session?.date ?? Dates.key() }

    func exercise(day: Int, index: Int) -> (RoutineDay, RoutineExercise)? {
        guard data.routine.days.indices.contains(day) else { return nil }
        let d = data.routine.days[day]
        guard d.exercises.indices.contains(index) else { return nil }
        return (d, d.exercises[index])
    }

    func entries(_ k: String) -> [HistoryEntry] { data.hist[k] ?? [] }

    /// La anotación actual: la del entrenamiento en curso, o la suelta de hoy si no hay ninguno.
    private func isCurrent(_ e: HistoryEntry) -> Bool {
        e.date == workDate && e.session == data.session?.id
    }

    func todayEntry(_ k: String) -> HistoryEntry? {
        entries(k).last(where: isCurrent)
    }

    func lastEntry(_ k: String, excludingToday: Bool) -> HistoryEntry? {
        entries(k).last { $0.hasDone && !(excludingToday && isCurrent($0)) }
    }

    /// Mejor peso de todas las veces anteriores (incluso de otro entrenamiento hoy).
    func bestPast(_ k: String) -> Double? {
        entries(k).filter { !isCurrent($0) }.compactMap(\.top).max()
    }

    func progress(_ k: String) -> [ProgressPoint] {
        entries(k)
            .enumerated()
            .filter { $0.element.hasDone }
            .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .compactMap { item in item.element.top.map { ProgressPoint(date: item.element.date, weight: $0) } }
    }

    func status(_ ex: RoutineExercise) -> ExerciseStatus {
        let t = todayEntry(ex.key)
        let n = t.map { e in e.done.prefix(ex.series).filter { $0 }.count } ?? 0
        return ExerciseStatus(done: n, all: n >= ex.series, record: t?.prW)
    }

    /// La anotación de hoy, o una nueva con los pesos de la última vez (sin guardarla).
    func entryOrSeed(_ ex: RoutineExercise, dayName: String) -> HistoryEntry {
        if var e = todayEntry(ex.key) {
            pad(&e, to: ex.series)
            return e
        }
        let seed = lastEntry(ex.key, excludingToday: true)?.sets ?? []
        let sets = (0..<ex.series).map { i in i < seed.count ? seed[i] : (seed.last ?? 0) }
        return HistoryEntry(
            date: workDate, sets: sets, done: Array(repeating: false, count: ex.series),
            day: dayName, session: data.session?.id
        )
    }

    func lastDate(of day: RoutineDay) -> String? {
        day.exercises.compactMap { lastEntry($0.key, excludingToday: false)?.date }.max()
    }

    func previousLog(before log: SessionLog) -> SessionLog? {
        data.log.last { $0.dayName == log.dayName && $0.start < log.start }
    }

    // MARK: - Series y pesos

    private func pad(_ e: inout HistoryEntry, to n: Int) {
        while e.sets.count < n { e.sets.append(e.sets.last ?? 0) }
        while e.done.count < e.sets.count { e.done.append(false) }
    }

    /// Guarda la anotación de hoy (creándola si hace falta) y devuelve su posición.
    @discardableResult
    private func ensureEntry(_ ex: RoutineExercise, dayName: String) -> Int {
        let e = entryOrSeed(ex, dayName: dayName)
        var list = entries(ex.key)
        if let i = list.firstIndex(where: isCurrent) {
            list[i] = e
            data.hist[ex.key] = list
            return i
        }
        list.append(e)
        data.hist[ex.key] = list
        return list.count - 1
    }

    func openExercise(dayIndex: Int, exerciseIndex: Int) {
        guard case let (day, ex)? = exercise(day: dayIndex, index: exerciseIndex) else { return }
        ensureEntry(ex, dayName: day.name)
        if data.session?.dayIndex == dayIndex, !status(ex).all {
            data.session?.currentKey = ex.key
        }
        commit()
    }

    func changeWeight(dayIndex: Int, exerciseIndex: Int, set i: Int, up: Bool) {
        guard case let (day, ex)? = exercise(day: dayIndex, index: exerciseIndex) else { return }
        changeWeight(ex, dayName: day.name, set: i, up: up)
    }

    private func changeWeight(_ ex: RoutineExercise, dayName: String, set i: Int, up: Bool) {
        let idx = ensureEntry(ex, dayName: dayName)
        var e = data.hist[ex.key]![idx]
        guard e.sets.indices.contains(i) else { return }
        e.sets[i] = up ? e.sets[i] + data.step : max(0, e.sets[i] - data.step)
        // Las series que todavía no hiciste copian el peso nuevo.
        for j in (i + 1)..<e.sets.count where !e.done[j] {
            e.sets[j] = e.sets[i]
        }
        data.hist[ex.key]![idx] = e
        checkRecord(ex, raised: up)
        commit(touch: true)
    }

    func toggleSet(dayIndex: Int, exerciseIndex: Int, set i: Int) {
        guard case let (day, ex)? = exercise(day: dayIndex, index: exerciseIndex) else { return }
        let idx = ensureEntry(ex, dayName: day.name)
        guard data.hist[ex.key]![idx].done.indices.contains(i) else { return }
        data.hist[ex.key]![idx].done[i].toggle()
        checkRecord(ex, raised: data.hist[ex.key]![idx].done[i])
        if data.session?.dayIndex == dayIndex {
            advanceIfFinished(ex)
            if finishIfDayComplete() { return }
        }
        commit(touch: true)
    }

    func setStep(_ step: Double) {
        data.step = step
        commit()
    }

    // MARK: - Récords

    private func checkRecord(_ ex: RoutineExercise, raised: Bool) {
        let k = ex.key
        guard let idx = entries(k).firstIndex(where: isCurrent) else { return }
        var e = data.hist[k]![idx]
        let best = bestPast(k)
        var top: Double?
        if let best {
            for (w, d) in zip(e.sets, e.done) where d && w > best {
                top = max(top ?? w, w)
            }
        }
        let before = e.prW ?? 0
        e.prW = top
        data.hist[k]![idx] = e
        if raised, let top, top > before, let best {
            celebrate(ex.name, weight: top, previous: best)
        }
    }

    private func celebrate(_ name: String, weight: Double, previous: Double) {
        if UIApplication.shared.applicationState == .active {
            celebration = Celebration(name: name, weight: weight, previous: previous)
            Haptics.celebrate()
        } else {
            // App cerrada (botón de la pantalla de bloqueo): aviso que también vibra en el reloj.
            notificationTasks.append(Task {
                await Notifier.record(name: name, weight: weight, previous: previous)
            })
        }
    }

    func dismissCelebration(_ id: UUID) {
        if celebration?.id == id { celebration = nil }
    }

    // MARK: - Entrenamiento

    private var sessionDay: RoutineDay? {
        guard let s = data.session, data.routine.days.indices.contains(s.dayIndex) else { return nil }
        return data.routine.days[s.dayIndex]
    }

    private var current: (day: RoutineDay, ex: RoutineExercise)? {
        guard let day = sessionDay, let k = data.session?.currentKey,
              let ex = day.exercises.first(where: { $0.key == k }) else { return nil }
        return (day, ex)
    }

    private func currentSetIndex(_ e: HistoryEntry, series: Int) -> Int? {
        (0..<min(series, e.done.count)).first { !e.done[$0] }
    }

    /// Próximo ejercicio sin terminar, en el orden de la rutina y dando la vuelta.
    private func nextPendingKey(after key: String?) -> String? {
        guard let list = sessionDay?.exercises, !list.isEmpty else { return nil }
        var order = list
        if let key, let i = list.firstIndex(where: { $0.key == key }) {
            order = Array(list[(i + 1)...]) + Array(list[...i])
        }
        if let next = order.first(where: { $0.key != key && !status($0).all }) { return next.key }
        if let key, let same = list.first(where: { $0.key == key }), !status(same).all { return key }
        return nil
    }

    private func advanceIfFinished(_ ex: RoutineExercise) {
        guard data.session?.currentKey == ex.key, status(ex).all else { return }
        // Primero se calcula y después se asigna: leer `data` mientras se modifica cierra la app.
        let next = nextPendingKey(after: ex.key)
        data.session?.currentKey = next
    }

    /// Con todos los ejercicios del día hechos, el entrenamiento se cierra solo y muestra el resumen.
    private func finishIfDayComplete() -> Bool {
        guard let day = sessionDay, !day.exercises.isEmpty,
              day.exercises.allSatisfy({ status($0).all }) else { return false }
        finishSession(fromLockScreen: UIApplication.shared.applicationState != .active)
        return true
    }

    func startSession(dayIndex: Int) {
        guard data.routine.days.indices.contains(dayIndex) else { return }
        if data.session != nil { finishSession(fromLockScreen: false, showSummary: false) }
        let day = data.routine.days[dayIndex]
        let now = Date()
        data.session = Session(
            dayIndex: dayIndex, dayName: day.name, start: now, date: Dates.key(now),
            currentKey: nil, confirmingEnd: false, lastActivity: now, id: UUID()
        )
        let first = nextPendingKey(after: nil)
        data.session?.currentKey = first
        save()
        startLiveActivity()
        Task { _ = await Notifier.requestPermission() }
    }

    /// Termina el entrenamiento y deja el resumen listo para mostrar.
    func finishSession(fromLockScreen: Bool, showSummary: Bool = true, end: Date = Date()) {
        guard let s = data.session else { return }
        let log = makeLog(s, end: end)
        data.log.append(log)
        data.session = nil
        if showSummary { data.pendingSummary = log.id }
        purgeDrafts(keepCurrent: false)
        save()

        let targets = Activity<WorkoutAttributes>.activities
        if fromLockScreen {
            // En la pantalla de bloqueo queda el resumen unos minutos.
            let final = ActivityContent(state: finishedState(s, log), staleDate: nil)
            let policy = ActivityUIDismissalPolicy.after(Date().addingTimeInterval(10 * 60))
            enqueueLive { for a in targets { await a.end(final, dismissalPolicy: policy) } }
        } else {
            enqueueLive { for a in targets { await a.end(nil, dismissalPolicy: .immediate) } }
        }
    }

    func takePendingSummary() -> SessionLog? {
        guard let id = data.pendingSummary else { return nil }
        data.pendingSummary = nil
        save()
        return data.log.first { $0.id == id }
    }

    private func makeLog(_ s: Session, end: Date) -> SessionLog {
        let exercises = data.routine.days.indices.contains(s.dayIndex) ? data.routine.days[s.dayIndex].exercises : []
        var done = 0, sets = 0, volume = 0.0
        var prs: [PRItem] = []
        for ex in exercises {
            let list = entries(ex.key)
            let mine = { (e: HistoryEntry) in e.date == s.date && e.session == s.id }
            guard let e = list.last(where: mine) else { continue }
            let w = e.doneWeights
            if !w.isEmpty { done += 1 }
            sets += w.count
            volume += w.reduce(0, +) * Double(repsNumber(ex.reps))
            if let pr = e.prW, let prev = list.filter({ !mine($0) }).compactMap(\.top).max() {
                prs.append(PRItem(name: ex.name, weight: pr, previous: prev))
            }
        }
        return SessionLog(
            dayName: s.dayName, start: s.start, end: end, exercisesDone: done,
            exercisesTotal: exercises.count, sets: sets, volume: volume, prs: prs
        )
    }

    /// Borra las anotaciones abiertas que quedaron sin ninguna serie hecha.
    private func purgeDrafts(keepCurrent: Bool) {
        for (k, list) in data.hist {
            let kept = list.filter { $0.hasDone || (keepCurrent && isCurrent($0)) }
            if kept.count != list.count { data.hist[k] = kept.isEmpty ? nil : kept }
        }
    }

    /// Al abrir la app: cerrar entrenamientos olvidados y ordenar la Live Activity.
    func onForeground() {
        if let s = data.session {
            let last = s.lastActivity ?? s.start
            if Date().timeIntervalSince(last) > 5 * 3600 {
                finishSession(fromLockScreen: false, end: last)
            }
        }
        purgeDrafts(keepCurrent: true)
        save()
        if data.session != nil {
            let running = Activity<WorkoutAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
            if running.isEmpty { startLiveActivity() } else { pushLiveActivity() }
        } else {
            endAllActivities()
        }
    }

    // MARK: - Botones de la pantalla de bloqueo

    /// Cada botón dice qué ejercicio y serie estaba mostrando. Si ya no coincide
    /// (toque repetido, o el reloj mostraba algo viejo), no se hace nada y solo se refresca.
    private func matchesShown(_ exercise: String, _ setNumber: Int) -> Bool {
        guard let c = current else { return false }
        let e = entryOrSeed(c.ex, dayName: c.day.name)
        guard let i = currentSetIndex(e, series: c.ex.series) else { return false }
        return c.ex.name == exercise && i + 1 == setNumber
    }

    func adjustCurrentWeight(up: Bool, exercise: String, setNumber: Int) {
        guard data.session != nil else { return endAllActivities() }
        guard matchesShown(exercise, setNumber), let c = current else { return pushLiveActivity() }
        let e = entryOrSeed(c.ex, dayName: c.day.name)
        guard let i = currentSetIndex(e, series: c.ex.series) else { return }
        changeWeight(c.ex, dayName: c.day.name, set: i, up: up)
    }

    func completeCurrentSet(exercise: String, setNumber: Int) {
        guard data.session != nil else { return endAllActivities() }
        guard matchesShown(exercise, setNumber), let c = current else { return pushLiveActivity() }
        let idx = ensureEntry(c.ex, dayName: c.day.name)
        guard let i = currentSetIndex(data.hist[c.ex.key]![idx], series: c.ex.series) else { return }
        data.hist[c.ex.key]![idx].done[i] = true
        checkRecord(c.ex, raised: true)
        advanceIfFinished(c.ex)
        if finishIfDayComplete() { return }
        commit(touch: true)
    }

    func skipCurrentExercise(exercise: String) {
        guard data.session != nil else { return endAllActivities() }
        guard current?.ex.name == exercise else { return pushLiveActivity() }
        let next = nextPendingKey(after: data.session?.currentKey)
        data.session?.currentKey = next
        commit()
    }

    func setConfirmingEnd(_ on: Bool) {
        guard data.session != nil else { return endAllActivities() }
        data.session?.confirmingEnd = on
        commit()
    }

    /// Espera a que terminen los cambios en la Live Activity y los avisos.
    func drain() async {
        await liveChain?.value
        let tasks = notificationTasks
        notificationTasks.removeAll()
        for t in tasks { await t.value }
    }

    // MARK: - Importar rutina

    /// Reemplaza la rutina. El historial queda: va por nombre de ejercicio.
    func applyImport(_ r: ImportedRoutine) {
        if data.session != nil { finishSession(fromLockScreen: false, showSummary: false) }
        let days = r.days.map { d in
            RoutineDay(
                name: d.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Día" : d.name.trimmingCharacters(in: .whitespaces),
                exercises: d.exercises.map { RoutineExercise(name: $0.name, series: max(1, $0.series), reps: $0.reps) }
            )
        }
        data.routine = Routine(profe: r.profe.isEmpty ? data.routine.profe : r.profe, days: days)
        commit()
    }

    // MARK: - Reiniciar estadísticas

    func clearDemo() {
        // Los pesos de ejemplo son los que no tienen día anotado.
        for (k, list) in data.hist {
            let kept = list.filter { $0.day != nil }
            data.hist[k] = kept.isEmpty ? nil : kept
        }
        data.demo = false
        commit()
    }

    func resetDay(_ dayIndex: Int) {
        guard data.routine.days.indices.contains(dayIndex) else { return }
        let day = data.routine.days[dayIndex]
        let keys = Set(day.exercises.map(\.key))
        for (k, list) in data.hist {
            let kept = list.filter { e in
                if let d = e.day { return d != day.name }
                return !keys.contains(k)
            }
            if kept.count != list.count { data.hist[k] = kept.isEmpty ? nil : kept }
        }
        data.log.removeAll { $0.dayName == day.name }
        commit()
    }

    func resetAll() {
        data.hist = [:]
        data.log = []
        data.demo = false
        commit()
    }

    // MARK: - Live Activity

    private func commit(touch: Bool = false) {
        if touch { data.session?.lastActivity = Date() }
        save()
        pushLiveActivity()
    }

    func liveState() -> WorkoutAttributes.ContentState? {
        guard let s = data.session else { return nil }
        let day = sessionDay
        var st = WorkoutAttributes.ContentState(
            startDate: s.start, dayName: s.dayName, exercise: nil, setNumber: 0, setCount: 0,
            reps: "", weight: 0, recordPace: false,
            doneExercises: day?.exercises.filter { status($0).all }.count ?? 0,
            totalExercises: day?.exercises.count ?? 0,
            confirmingEnd: s.confirmingEnd, finishedSummary: nil
        )
        if let c = current {
            let e = entryOrSeed(c.ex, dayName: c.day.name)
            if let i = currentSetIndex(e, series: c.ex.series) {
                st.exercise = c.ex.name
                st.setNumber = i + 1
                st.setCount = c.ex.series
                st.reps = c.ex.reps
                st.weight = e.sets[i]
                if let best = bestPast(c.ex.key) { st.recordPace = e.sets[i] > best }
            }
        }
        return st
    }

    private func finishedState(_ s: Session, _ log: SessionLog) -> WorkoutAttributes.ContentState {
        var summary = "\(formatElapsed(log.duration)) · \(log.sets) series · \(fmtThousands(log.volume)) kg"
        if !log.prs.isEmpty { summary += " · \(log.prs.count) récord\(log.prs.count > 1 ? "s" : "")" }
        return WorkoutAttributes.ContentState(
            startDate: s.start, dayName: s.dayName, exercise: nil, setNumber: 0, setCount: 0,
            reps: "", weight: 0, recordPace: false, doneExercises: log.exercisesDone,
            totalExercises: log.exercisesTotal, confirmingEnd: false, finishedSummary: summary
        )
    }

    /// Las actualizaciones van en fila para que lleguen en orden.
    private func enqueueLive(_ work: @escaping () async -> Void) {
        let previous = liveChain
        liveChain = Task {
            await previous?.value
            await work()
        }
    }

    private func pushLiveActivity() {
        guard let state = liveState() else { return }
        let targets = Activity<WorkoutAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
        let content = ActivityContent(state: state, staleDate: nil)
        enqueueLive { for a in targets { await a.update(content) } }
    }

    private func startLiveActivity() {
        guard let state = liveState() else { return }
        let old = Activity<WorkoutAttributes>.activities
        if !old.isEmpty {
            enqueueLive { for a in old { await a.end(nil, dismissalPolicy: .immediate) } }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(
                attributes: WorkoutAttributes(title: "Entrenando"),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("No se pudo iniciar la Live Activity: \(error)")
        }
    }

    private func endAllActivities() {
        let all = Activity<WorkoutAttributes>.activities
        guard !all.isEmpty else { return }
        enqueueLive { for a in all { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}
