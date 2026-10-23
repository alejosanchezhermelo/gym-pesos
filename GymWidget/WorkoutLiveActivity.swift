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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Serie \(state.setNumber) de \(state.setCount) · \(state.reps) reps")
                    .font(.display(14, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button(intent: SkipExerciseIntent(exercise: state.exercise ?? "")) {
                    SmallChip(title: "Saltar", systemImage: "forward.fill")
                }
                .buttonStyle(.plain)
                Button(intent: AskEndIntent()) {
                    SmallChip(title: "Terminar", systemImage: nil)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Button(intent: AdjustWeightIntent(up: false, exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                    StepperKey(systemImage: "minus")
                }
                .buttonStyle(.plain)
                WeightLabel(weight: state.weight, record: state.recordPace, size: 30)
                    .frame(minWidth: 64)
                Button(intent: AdjustWeightIntent(up: true, exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                    StepperKey(systemImage: "plus")
                }
                .buttonStyle(.plain)
                Button(intent: CompleteSetIntent(exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                    WideKey(title: "Serie hecha", systemImage: "checkmark", fill: Palette.accent, ink: Palette.accentInk)
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
                        Text("\(fmtW(state.weight)) kg")
                            .font(.display(20, weight: .bold))
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
                HStack(spacing: 8) {
                    Button(intent: AdjustWeightIntent(up: false, exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                        StepperKey(systemImage: "minus")
                    }
                    .buttonStyle(.plain)
                    WeightLabel(weight: state.weight, record: state.recordPace, size: 26)
                        .frame(minWidth: 58)
                    Button(intent: AdjustWeightIntent(up: true, exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                        StepperKey(systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    Button(intent: CompleteSetIntent(exercise: state.exercise ?? "", setNumber: state.setNumber)) {
                        WideKey(title: "Serie hecha", systemImage: "checkmark", fill: Palette.accent, ink: Palette.accentInk)
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

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Palette.fg)
            .frame(width: 46, height: 46)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface2))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }
}

struct WideKey: View {
    let title: String
    let systemImage: String?
    let fill: Color
    let ink: Color

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
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(RoundedRectangle(cornerRadius: 12).fill(fill))
    }
}

struct SmallChip: View {
    let title: String
    let systemImage: String?

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
        .frame(height: 28)
        .background(Capsule().fill(Palette.surface2))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
    }
}

struct WeightLabel: View {
    let weight: Double
    let record: Bool
    let size: CGFloat

    var body: some View {
        VStack(spacing: -2) {
            Text(fmtW(weight))
                .font(.display(size, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(record ? Palette.gold : Palette.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(record ? "kg · récord" : "kg")
                .font(.display(10, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(record ? Palette.gold : Palette.muted)
        }
    }
}
