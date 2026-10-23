import SwiftUI

/// Hoja de un ejercicio: peso y reps de cada serie con + y −, progreso e historial.
struct ExerciseSheet: View {
    let dayIndex: Int
    let exerciseIndex: Int

    @Environment(\.dismiss) private var dismiss
    private var store: Store { Store.shared }

    var body: some View {
        if let pair = store.exercise(day: dayIndex, index: exerciseIndex) {
            content(day: pair.0, ex: pair.1)
        } else {
            Color.clear
        }
    }

    private func content(day: RoutineDay, ex: RoutineExercise) -> some View {
        let k = ex.key
        let bodyweight = ex.isBodyweight
        let entry = store.entryOrSeed(ex, dayName: day.name)
        let best = store.bestPast(ex)
        let prev = store.lastEntry(k, excludingToday: true)
        let points = Array(store.progress(ex).suffix(10))
        let today = store.workDate
        let history = Array(store.entries(k).filter { $0.date != today && $0.hasDone }.suffix(4).reversed())
        let allDone = store.status(ex).all
        let record = entry.prW.map { SetScore(weight: $0, reps: entry.prR ?? 0) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(ex.series) series × \(ex.reps) reps").eyebrow()
                        Text(ex.name)
                            .font(.display(32, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.fg)
                    }
                    Spacer(minLength: 4)
                    if let record {
                        RecordChip(text: scoreText(record, bodyweight: bodyweight))
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    ExerciseFigure(name: ex.name)
                        .frame(width: 150)
                    ProgressChartBox(points: points, today: today, unit: bodyweight ? "reps" : "kg")
                }
                .frame(height: 150)

                previousLine(prev, ex)

                Toggle(isOn: Binding(
                    get: { bodyweight },
                    set: { store.setBodyweight(dayIndex: dayIndex, exerciseIndex: exerciseIndex, $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sin peso")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.fg)
                        Text("Con el peso del cuerpo: cuentan solo las reps.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                    }
                }
                .tint(Palette.accent)

                if !bodyweight {
                    StepChips(step: store.data.step) { store.setStep($0) }
                }

                VStack(spacing: 8) {
                    ForEach(0..<ex.series, id: \.self) { i in
                        let done = entry.done[i]
                        let s = store.score(entry, i, ex)
                        SetRow(
                            index: i,
                            weight: entry.sets[i],
                            reps: s.reps,
                            bodyweight: bodyweight,
                            done: done,
                            record: done && (best.map { s > $0 } ?? false),
                            weightMinus: { store.changeWeight(dayIndex: dayIndex, exerciseIndex: exerciseIndex, set: i, up: false) },
                            weightPlus: { store.changeWeight(dayIndex: dayIndex, exerciseIndex: exerciseIndex, set: i, up: true) },
                            repsMinus: { store.changeReps(dayIndex: dayIndex, exerciseIndex: exerciseIndex, set: i, up: false) },
                            repsPlus: { store.changeReps(dayIndex: dayIndex, exerciseIndex: exerciseIndex, set: i, up: true) },
                            toggle: { store.toggleSet(dayIndex: dayIndex, exerciseIndex: exerciseIndex, set: i) }
                        )
                    }
                }

                if !history.isEmpty {
                    HistoryList(
                        lines: history.map { (Dates.short($0.date), store.doneText($0, ex)) },
                        best: best.map { scoreText($0, bodyweight: bodyweight) }
                    )
                }

                BigButton(title: "Listo") { dismiss() }
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.success, trigger: allDone) { _, new in new }
    }

    @ViewBuilder
    private func previousLine(_ prev: HistoryEntry?, _ ex: RoutineExercise) -> some View {
        if let prev {
            (Text("Última vez (\(Dates.short(prev.date))): ")
                + Text(store.doneText(prev, ex))
                .fontWeight(.semibold)
                .foregroundColor(Palette.fg))
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        } else {
            Text(ex.isBodyweight ? "Primera vez: cargá las reps de cada serie." : "Primera vez: cargá el peso y las reps de cada serie.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        }
    }
}

private struct StepChips: View {
    let step: Double
    let choose: (Double) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("Salto")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .padding(.trailing, 4)
            ForEach([1.0, 2.5, 5.0], id: \.self) { s in
                Button { choose(s) } label: {
                    Text("\(fmtW(s)) kg")
                        .font(.display(16, weight: .semibold))
                        .foregroundStyle(step == s ? Palette.accentInk : Palette.fg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(step == s ? Palette.accent : Color.clear))
                        .overlay(Capsule().stroke(step == s ? Palette.accent : Palette.line, lineWidth: 1))
                }
                .buttonStyle(PressScale())
            }
        }
    }
}

/// Una serie: peso (si lleva) y reps, cada uno con − y +, y el tilde a la derecha.
private struct SetRow: View {
    let index: Int
    let weight: Double
    let reps: Int
    let bodyweight: Bool
    let done: Bool
    let record: Bool
    let weightMinus: () -> Void
    let weightPlus: () -> Void
    let repsMinus: () -> Void
    let repsPlus: () -> Void
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("S\(index + 1)")
                    .font(.display(22, weight: .bold))
                    .foregroundStyle(Palette.fg)
                if record {
                    Text("Récord")
                        .font(.display(12, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.gold)
                }
            }
            .frame(width: 48, alignment: .leading)

            VStack(spacing: 6) {
                if !bodyweight {
                    StepperLine(
                        value: fmtW(weight), unit: "kg", size: 34, key: 52,
                        label: "peso serie \(index + 1)", minus: weightMinus, plus: weightPlus
                    )
                }
                StepperLine(
                    value: "\(reps)", unit: "reps", size: bodyweight ? 34 : 24, key: bodyweight ? 52 : 40,
                    label: "reps serie \(index + 1)", minus: repsMinus, plus: repsPlus
                )
            }

            Button(action: toggle) {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(done ? Palette.accentInk : Palette.muted)
                    .frame(width: 56)
                    .frame(maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14).fill(done ? Palette.accent : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(done ? Palette.accent : Palette.line, lineWidth: 2))
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("Marcar serie \(index + 1)")
            .sensoryFeedback(.impact(weight: .medium), trigger: done)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(done ? Palette.accent.opacity(0.12) : Palette.surface2))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(record ? Palette.gold : (done ? Palette.accent : Color.clear), lineWidth: 1))
        .sensoryFeedback(.impact(weight: .light), trigger: weight)
        .sensoryFeedback(.impact(weight: .light), trigger: reps)
    }
}

private struct StepperLine: View {
    let value: String
    let unit: String
    let size: CGFloat
    let key: CGFloat
    let label: String
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            KeyButton(systemImage: "minus", size: key, label: "Bajar \(label)", action: minus)
            (Text(value).font(.display(size, weight: .bold))
                + Text(unit).font(.display(14, weight: .semibold)).foregroundColor(Palette.muted))
                .monospacedDigit()
                .foregroundStyle(Palette.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
            KeyButton(systemImage: "plus", size: key, label: "Subir \(label)", action: plus)
        }
    }
}

private struct KeyButton: View {
    let systemImage: String
    let size: CGFloat
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Palette.fg)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.bg))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(label)
    }
}

private struct HistoryList: View {
    let lines: [(String, String)]
    let best: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(best.map { "Historial · mejor \($0)" } ?? "Historial").eyebrow(12)
            ForEach(Array(lines.enumerated()), id: \.offset) { item in
                HStack {
                    Text(item.element.0)
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Text(item.element.1)
                        .monospacedDigit()
                        .foregroundStyle(Palette.fg)
                }
                .font(.system(size: 15))
            }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
    }
}
