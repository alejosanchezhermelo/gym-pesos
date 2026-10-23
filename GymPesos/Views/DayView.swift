import SwiftUI

/// Un día de la rutina: lista de ejercicios y, abajo, arrancar / cronómetro.
struct DayView: View {
    let dayIndex: Int
    var back: () -> Void
    var openExercise: (Int) -> Void

    private var store: Store { Store.shared }

    var body: some View {
        if store.routine.days.indices.contains(dayIndex) {
            content(store.routine.days[dayIndex])
        } else {
            Color.clear.onAppear(perform: back)
        }
    }

    private func content(_ day: RoutineDay) -> some View {
        let statuses = day.exercises.map { store.status($0) }
        let doneCount = statuses.filter(\.all).count
        let records = statuses.filter { $0.record != nil }.count
        let session = store.session
        let running = session?.dayIndex == dayIndex
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Día \(dayIndex + 1) de \(store.routine.days.count)").eyebrow()
                    Text(day.name)
                        .font(.display(44, weight: .heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.fg)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(doneCount)/\(day.exercises.count)")
                            .font(.display(28, weight: .bold))
                            .foregroundStyle(Palette.accent)
                        Text("ejercicios hechos")
                        if records > 0 {
                            Text("· \(records) \(records > 1 ? "récords" : "récord")")
                                .foregroundStyle(Palette.gold)
                        }
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 6)
                    Text("En el orden que quieras")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                }
                VStack(spacing: 10) {
                    ForEach(Array(day.exercises.enumerated()), id: \.element.id) { item in
                        ExerciseCard(
                            ex: item.element,
                            isCurrent: running && session?.currentKey == item.element.key
                        ) {
                            openExercise(item.offset)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Dock {
                DockIconButton(systemImage: "chevron.left", label: "Volver a los días", action: back)
                if let session, running {
                    RunPanel(start: session.start) { store.finishSession(fromLockScreen: false) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    SlideToStart(label: "Deslizá para arrancar") { store.startSession(dayIndex: dayIndex) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: running)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.startLocation.x < 40, value.translation.width > 80 { back() }
            }
        )
    }
}

private struct ExerciseCard: View {
    let ex: RoutineExercise
    let isCurrent: Bool
    let open: () -> Void

    private var store: Store { Store.shared }

    var body: some View {
        let st = store.status(ex)
        let shownEntry = st.done > 0 ? store.todayEntry(ex.key) : store.lastEntry(ex.key, excludingToday: true)
        let best = shownEntry.flatMap { store.bestDone($0, ex) }
        let shown: Double? = best.map { ex.isBodyweight ? Double($0.reps) : $0.weight }
        let points = Array(store.progress(ex).suffix(8))
        Button(action: open) {
            HStack(spacing: 14) {
                CheckCircle(status: st, series: ex.series)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ex.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.fg)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Text("\(ex.series) × \(ex.reps)")
                            .font(.display(15, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                        if points.count >= 2 {
                            Sparkline(points: points)
                                .frame(width: 56, height: 16)
                        }
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    cardLabel(st)
                        .font(.display(11, weight: .semibold))
                        .tracking(1.3)
                        .textCase(.uppercase)
                    weightText(shown, st, unit: ex.isBodyweight ? "reps" : "kg")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(st.all ? Palette.accent.opacity(0.12) : Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor(st), lineWidth: 1))
        }
        .buttonStyle(PressScale())
    }

    private func borderColor(_ st: ExerciseStatus) -> Color {
        if st.record != nil { return Palette.gold }
        if st.all { return Palette.accent }
        if isCurrent { return Palette.accent.opacity(0.5) }
        return Palette.line
    }

    @ViewBuilder
    private func cardLabel(_ st: ExerciseStatus) -> some View {
        if st.record != nil {
            Label("Récord", systemImage: "medal.fill")
                .foregroundStyle(Palette.gold)
        } else if isCurrent && !st.all {
            Text("Ahora")
                .foregroundStyle(Palette.accent)
        } else {
            Text(st.done > 0 ? "Hoy" : "Último")
                .foregroundStyle(Palette.muted)
        }
    }

    private func weightText(_ shown: Double?, _ st: ExerciseStatus, unit: String) -> some View {
        let color: Color = st.record != nil ? Palette.gold : (st.all ? Palette.accent : Palette.fg)
        return (Text(shown.map(fmtW) ?? "—").font(.display(34, weight: .bold)).foregroundColor(color)
            + Text(shown == nil ? "" : unit).font(.display(15, weight: .semibold)).foregroundColor(Palette.muted))
            .monospacedDigit()
    }
}

private struct CheckCircle: View {
    let status: ExerciseStatus
    let series: Int

    var body: some View {
        ZStack {
            Circle().fill(status.all ? Palette.accent : Color.clear)
            Circle().stroke(status.done > 0 ? Palette.accent : Palette.line, lineWidth: 2)
            if status.all {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Palette.accentInk)
            } else if status.done > 0 {
                Text("\(status.done)/\(series)")
                    .font(.display(12, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
        }
        .frame(width: 34, height: 34)
    }
}
