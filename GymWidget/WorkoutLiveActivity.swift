import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Cronómetro que cuenta solo (estilo timer de SwiftUI), sin push ni actualizaciones.
private func timerText(_ start: Date) -> Text {
    Text(timerInterval: start...Date.distantFuture, countsDown: false)
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            ActivityContentView(state: context.state)
                .activityBackgroundTint(Palette.bg)
                .activitySystemActionForegroundColor(Palette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandLeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    IslandTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exercise ?? context.state.dayName)
                        .font(.display(17, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.fg)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IslandBottom(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Palette.accent)
            } compactTrailing: {
                CompactTrailing(state: context.state)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Palette.accent)
            }
            .keylineTint(Palette.accent)
        }
        // Vista propia para el Apple Watch (Smart Stack).
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Pantalla de bloqueo / reloj

struct ActivityContentView: View {
    let state: WorkoutAttributes.ContentState
    @Environment(\.activityFamily) private var family

    var body: some View {
        if family == .small {
            WatchActivityView(state: state)
        } else {
            LockScreenActivityView(state: state)
        }
    }
}

struct LockScreenActivityView: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.display(21, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if state.exercise != nil && state.finishedSummary == nil && !state.confirmingEnd {
                    Text("S\(state.setNumber)/\(state.setCount)")
                        .font(.display(16, weight: .bold))
                        .foregroundStyle(Palette.muted)
                }
                if state.finishedSummary == nil {
                    timerText(state.startDate)
                        .font(.display(24, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 96, alignment: .trailing)
                }
            }
            if let summary = state.finishedSummary {
                finished(summary)
            } else if state.confirmingEnd {
                confirmEnd
            } else if state.exercise != nil {
                controls
            } else {
                dayComplete
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var title: String {
        if state.finishedSummary != nil { return "\(state.dayName) · listo" }
        return state.exercise ?? state.dayName
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            SetSteppers(state: state, key: 44, size: 28)
            HStack(spacing: 6) {
                Button(intent: CompleteSetIntent(exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                    WideKey(title: "Serie hecha", systemImage: "checkmark", fill: Palette.accent, ink: Palette.accentInk, height: 40)
                }
                .buttonStyle(.plain)
                Button(intent: SkipExerciseIntent(exercise: state.exercise ?? "")) {
                    SmallChip(title: "Saltar", systemImage: "forward.fill", height: 40)
                }
                .buttonStyle(.plain)
                Button(intent: AskEndIntent()) {
                    SmallChip(title: "Terminar", systemImage: nil, height: 40)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var confirmEnd: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("¿Terminar el entrenamiento?")
                .font(.display(16, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Palette.warn)
            HStack(spacing: 8) {
                Button(intent: CancelEndIntent()) {
                    WideKey(title: "No, seguir", systemImage: nil, fill: Palette.surface2, ink: Palette.fg)
                }
                .buttonStyle(.plain)
                Button(intent: ConfirmEndIntent()) {
                    WideKey(title: "Sí, terminar", systemImage: nil, fill: Palette.warn, ink: Palette.accentInk)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dayComplete: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("¡Día completo! · \(state.doneExercises)/\(state.totalExercises) ejercicios")
                .font(.display(16, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Palette.accent)
            Button(intent: AskEndIntent()) {
                WideKey(title: "Terminar entrenamiento", systemImage: nil, fill: Palette.accent, ink: Palette.accentInk)
            }
            .buttonStyle(.plain)
        }
    }

    private func finished(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary)
                .font(.display(22, weight: .bold))
                .foregroundStyle(Palette.accent)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("Abrí la app para ver el resumen completo.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
        }
    }
}

/// Smart Stack del Apple Watch: un solo botón, como recomienda Apple.
struct WatchActivityView: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(state.exercise ?? state.dayName)
                    .font(.display(15, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if state.finishedSummary == nil {
                    timerText(state.startDate)
                        .font(.display(13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 50, alignment: .trailing)
                }
            }
            if let summary = state.finishedSummary {
                Text(summary)
                    .font(.display(14, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .lineLimit(2)
            } else if state.confirmingEnd {
                Button(intent: ConfirmEndIntent()) {
                    Text("Sí, terminar")
                        .font(.display(14, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.accentInk)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(Capsule().fill(Palette.warn))
                }
                .buttonStyle(.plain)
            } else if state.exercise != nil {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Serie \(state.setNumber)/\(state.setCount)")
                            .font(.display(11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.muted)
                        Text(state.bodyweight ? "\(state.setReps) reps" : "\(fmtW(state.weight)) kg × \(state.setReps)")
                            .font(.display(20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(state.recordPace ? Palette.gold : Palette.fg)
                    }
                    Spacer(minLength: 2)
                    Button(intent: CompleteSetIntent(exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Palette.accentInk)
                            .frame(width: 46, height: 34)
                            .background(Capsule().fill(Palette.accent))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("¡Día completo!")
                    .font(.display(15, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Isla dinámica

struct IslandLeading: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "dumbbell.fill")
            if state.exercise != nil && state.finishedSummary == nil {
                Text("S\(state.setNumber)/\(state.setCount)")
            }
        }
        .font(.display(15, weight: .bold))
        .foregroundStyle(Palette.accent)
        .padding(.leading, 4)
    }
}

struct IslandTrailing: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        if state.finishedSummary == nil {
            timerText(state.startDate)
                .font(.display(18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.accent)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80, alignment: .trailing)
                .padding(.trailing, 4)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.accent)
                .padding(.trailing, 4)
        }
    }
}

struct IslandBottom: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        Group {
            if let summary = state.finishedSummary {
                Text(summary)
                    .font(.display(16, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if state.confirmingEnd {
                HStack(spacing: 8) {
                    Button(intent: CancelEndIntent()) {
                        WideKey(title: "No, seguir", systemImage: nil, fill: Palette.surface2, ink: Palette.fg)
                    }
                    .buttonStyle(.plain)
                    Button(intent: ConfirmEndIntent()) {
                        WideKey(title: "Sí, terminar", systemImage: nil, fill: Palette.warn, ink: Palette.accentInk)
                    }
                    .buttonStyle(.plain)
                }
            } else if state.exercise != nil {
                VStack(spacing: 6) {
                    SetSteppers(state: state, key: 38, size: 24)
                    Button(intent: CompleteSetIntent(exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                        WideKey(title: "Serie hecha", systemImage: "checkmark", fill: Palette.accent, ink: Palette.accentInk, height: 38)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(intent: AskEndIntent()) {
                    WideKey(title: "Terminar entrenamiento", systemImage: nil, fill: Palette.accent, ink: Palette.accentInk)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

struct CompactTrailing: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        if state.finishedSummary == nil {
            timerText(state.startDate)
                .font(.display(15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.accent)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 52)
        } else {
            Image(systemName: "checkmark")
                .foregroundStyle(Palette.accent)
        }
    }
}

// MARK: - Piezas

struct StepperKey: View {
    let systemImage: String
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(Palette.fg)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface2))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }
}

struct WideKey: View {
    let title: String
    let systemImage: String?
    let fill: Color
    let ink: Color
    var height: CGFloat = 46

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .heavy))
            }
            Text(title)
                .font(.display(17, weight: .bold))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(RoundedRectangle(cornerRadius: 12).fill(fill))
    }
}

struct SmallChip: View {
    let title: String
    let systemImage: String?
    var height: CGFloat = 28

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(title)
                .font(.display(13, weight: .bold))
                .textCase(.uppercase)
        }
        .foregroundStyle(Palette.fg)
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(Capsule().fill(Palette.surface2))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
    }
}

struct ValueLabel: View {
    let value: String
    let unit: String
    let record: Bool
    let size: CGFloat

    var body: some View {
        VStack(spacing: -2) {
            Text(value)
                .font(.display(size, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(record ? Palette.gold : Palette.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(record ? "\(unit) · récord" : unit)
                .font(.display(10, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(record ? Palette.gold : Palette.muted)
                .lineLimit(1)
        }
    }
}

/// [−] 42,5 kg [+]   [−] 12 reps [+]  (sin peso: solo las reps).
struct SetSteppers: View {
    let state: WorkoutAttributes.ContentState
    let key: CGFloat
    let size: CGFloat

    var body: some View {
        let ex = state.exercise ?? ""
        HStack(spacing: 6) {
            if !state.bodyweight {
                Button(intent: AdjustWeightIntent(up: false, exercise: ex, setNumber: state.setNumber)) {
                    StepperKey(systemImage: "minus", size: key)
                }
                .buttonStyle(.plain)
                ValueLabel(value: fmtW(state.weight), unit: "kg", record: state.recordPace, size: size)
                    .frame(minWidth: 50)
                Button(intent: AdjustWeightIntent(up: true, exercise: ex, setNumber: state.setNumber)) {
                    StepperKey(systemImage: "plus", size: key)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            Button(intent: AdjustRepsIntent(up: false, exercise: ex, setNumber: state.setNumber)) {
                StepperKey(systemImage: "minus", size: key)
            }
            .buttonStyle(.plain)
            ValueLabel(value: "\(state.setReps)", unit: "reps", record: state.recordPace, size: size)
                .frame(minWidth: 40)
            Button(intent: AdjustRepsIntent(up: true, exercise: ex, setNumber: state.setNumber)) {
                StepperKey(systemImage: "plus", size: key)
            }
            .buttonStyle(.plain)
            if state.bodyweight { Spacer(minLength: 4) }
        }
    }
}
