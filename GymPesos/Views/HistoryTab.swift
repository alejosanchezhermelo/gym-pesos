import SwiftUI
import UIKit

/// Pestaña Historial: todos los entrenamientos, del más nuevo al más viejo.
struct HistoryTab: View {
    var openLog: (SessionLog) -> Void
    private var store: Store { Store.shared }

    var body: some View {
        let logs = Array(store.data.log.reversed())
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Historial")
                    .font(.display(40, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)
                Text("\(logs.count) entrenamiento\(logs.count == 1 ? "" : "s"). Tocá uno para ver el resumen.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)

                if logs.isEmpty {
                    Text("Todavía no terminaste ningún entrenamiento. Cuando termines uno, aparece acá.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 20)
                }

                ForEach(logs) { log in
                    Button { openLog(log) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label(log.start))
                                    .font(.display(13, weight: .bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Palette.muted)
                                Text(log.dayName)
                                    .font(.display(22, weight: .bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Palette.fg)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("\(formatElapsed(log.duration)) · \(log.sets) series · \(fmtThousands(log.volume)) kg")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 6)
                            if !log.prs.isEmpty {
                                Label("\(log.prs.count)", systemImage: "medal.fill")
                                    .font(.display(17, weight: .bold))
                                    .foregroundStyle(Palette.gold)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Palette.muted)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(log.prs.isEmpty ? Palette.line : Palette.gold.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(PressScale())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func label(_ date: Date) -> String {
        let rel = relativeDay(date)
        if rel == "hoy" || rel == "ayer" { return rel }
        return "\(SpanishDate.weekdayAndDay(date)) · \(Dates.short(date))"
    }
}

/// Cargar el peso corporal a mano.
struct BodyWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kg: Double = 75
    private var store: Store { Store.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Peso corporal").eyebrow()
                Text("¿Cuánto pesás hoy?")
                    .font(.display(34, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)
            }
            HStack(spacing: 12) {
                key("minus") { kg = max(20, (kg * 10 - 1).rounded() / 10) }
                (Text(fmtW(kg)).font(.display(64, weight: .bold))
                    + Text(" kg").font(.display(22, weight: .semibold)).foregroundColor(Palette.muted))
                    .monospacedDigit()
                    .foregroundStyle(Palette.fg)
                    .frame(maxWidth: .infinity)
                key("plus") { kg = min(300, (kg * 10 + 1).rounded() / 10) }
            }
            HStack(spacing: 8) {
                ForEach([-1.0, -0.5, 0.5, 1.0], id: \.self) { d in
                    Button {
                        kg = min(300, max(20, ((kg + d) * 10).rounded() / 10))
                    } label: {
                        Text("\(d > 0 ? "+" : "−")\(fmtW(abs(d)))")
                            .font(.display(17, weight: .bold))
                            .foregroundStyle(Palette.fg)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(Palette.surface2))
                    }
                    .buttonStyle(PressScale())
                }
            }
            if let list = store.data.bodyWeights, !list.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Últimos").eyebrow(12)
                    ForEach(list.suffix(4).reversed()) { w in
                        HStack {
                            Text(Dates.short(w.date)).foregroundStyle(Palette.muted)
                            Spacer()
                            Text("\(fmtW(w.kg)) kg").foregroundStyle(Palette.fg)
                        }
                        .font(.system(size: 15))
                    }
                }
            }
            Spacer()
            BigButton(title: "Guardar") {
                store.addBodyWeight(kg)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .sensoryFeedback(.selection, trigger: kg)
        .onAppear { if let w = store.bodyWeight { kg = w } }
    }

    private func key(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.fg)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface2))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressScale())
    }
}
