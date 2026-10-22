import ActivityKit
import SwiftUI
import WidgetKit

/// Cronómetro que cuenta solo (estilo timer de SwiftUI), sin push ni actualizaciones.
private func timerText(_ start: Date) -> Text {
    Text(timerInterval: start...Date.distantFuture, countsDown: false)
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            // Pantalla de bloqueo / banner
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle().fill(Palette.accent).frame(width: 8, height: 8)
                        Text(context.attributes.title.uppercased())
                            .font(.display(14, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(Palette.muted)
                    }
                    Text("PESOS DEL GYM")
                        .font(.display(20, weight: .heavy))
                        .foregroundStyle(Palette.fg)
                }
                Spacer()
                timerText(context.state.startDate)
                    .font(.display(48, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 170, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .activityBackgroundTint(Palette.bg)
            .activitySystemActionForegroundColor(Palette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(Palette.accent)
                        Text("ENTRENANDO")
                            .font(.display(14, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("GYM")
                        .font(.display(14, weight: .heavy))
                        .foregroundStyle(Palette.accent)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    timerText(context.state.startDate)
                        .font(.display(44, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Palette.accent)
            } compactTrailing: {
                timerText(context.state.startDate)
                    .font(.display(15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Palette.accent)
            }
            .keylineTint(Palette.accent)
        }
    }
}
