import SwiftUI

/// Hoja de un ejercicio: peso de cada serie con + y −, progreso e historial.
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
        let entry = store.entryOrSeed(ex, dayName: day.name)
        let best = store.bestPast(k)
        let prev = store.lastEntry(k, excludingToday: true)
        let points = Array(store.progress(k).suffix(10))
        let today = store.workDate
        let history = Array(store.entries(k).filter { $0.date != today && $0.hasDone }.suffix(4).reversed())
        let allDone = store.status(ex).all
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
                    if let pr = entry.prW {
                        RecordChip(weight: pr)
                    }
                }

                ProgressChartBox(points: points, today: today)

                previousLine(prev)

                StepChips(step: store.data.step) { store.setStep($0) }

                VStack(spacing: 8) {
                    ForEach(0..<ex.series, id: \.self) { i in
                        let weight = entry.sets[i]
                        let done = entry.done[i]
                        SetRow(
                            index: i,
                            weight: weight,
                            done: done,
                            record: done && (best.map { weight > $0 } ?? false),
                            reps: ex.reps,
                            minus: { store.changeWeight(dayIndex: dayIndex, exerciseIndex: exerciseIndex, set: i, up: false) },
                            plus: { store.changeWeight(dayIndex: dayIndex, exerciseIndex: exerciseIndex, set: i, up: true) },
                            toggle: { store.toggleSet(dayIndex: dayIndex, exerciseIndex: exerciseIndex, set: i) }
                        )
                    }
                }

                if !history.isEmpty {
                    HistoryList(entries: history, best: best)
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
    private func previousLine(_ prev: HistoryEntry?) -> some View {
        if let prev {
            (Text("Última vez (\(Dates.short(prev.date))): ")
                + Text(prev.doneWeights.map(fmtW).joined(separator: " · ") + " kg")
                .fontWeight(.semibold)
                .foregroundColor(Palette.fg))
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        } else {
            Text("Primera vez: cargá el peso de cada serie.")
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

private struct SetRow: View {
    let index: Int
    let weight: Double
    let done: Bool
    let record: Bool
    let reps: String
    let minus: () -> Void
    let plus: () -> Void
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("S\(index + 1)")
                    .font(.display(22, weight: .bold))
                    .foregroundStyle(Palette.fg)
                Text(record ? "Récord" : "\(reps) reps")
                    .font(.display(12, weight: record ? .bold : .regular))
                    .textCase(record ? .uppercase : nil)
                    .foregroundStyle(record ? Palette.gold : Palette.muted)
                    .lineLimit(1)
            }
            .frame(width: 52, alignment: .leading)

            KeyButton(systemImage: "minus", label: "Bajar peso serie \(index + 1)", action: minus)

            (Text(fmtW(weight)).font(.display(38, weight: .bold))
                + Text("kg").font(.display(15, weight: .semibold)).foregroundColor(Palette.muted))
                .monospacedDigit()
                .foregroundStyle(Palette.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)

            KeyButton(systemImage: "plus", label: "Subir peso serie \(index + 1)", action: plus)

            Button(action: toggle) {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(done ? Palette.accentInk : Palette.muted)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 14).fill(done ? Palette.accent : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(done ? Palette.accent : Palette.line, lineWidth: 2))
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("Marcar serie \(index + 1)")
            .sensoryFeedback(.impact(weight: .medium), trigger: done)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(done ? Palette.accent.opacity(0.12) : Palette.surface2))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(record ? Palette.gold : (done ? Palette.accent : Color.clear), lineWidth: 1))
        .sensoryFeedback(.impact(weight: .light), trigger: weight)
    }
}

private struct KeyButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.fg)
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.bg))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(label)
    }
}

private struct HistoryList: View {
    let entries: [HistoryEntry]
    let best: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(best.map { "Historial · mejor \(fmtW($0)) kg" } ?? "Historial").eyebrow(12)
            ForEach(Array(entries.enumerated()), id: \.offset) { item in
                HStack {
                    Text(Dates.short(item.element.date))
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Text(item.element.doneWeights.map(fmtW).joined(separator: " · ") + " kg")
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
