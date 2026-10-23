import SwiftUI

/// Resumen al terminar: duración, kilos, series, récords y comparación con la vez anterior.
struct SummarySheet: View {
    let log: SessionLog

    @Environment(\.dismiss) private var dismiss
    private var store: Store { Store.shared }

    var body: some View {
        let prev = store.previousLog(before: log)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entrenamiento terminado").eyebrow()
                    Text(log.dayName)
                        .font(.display(38, weight: .heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.fg)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatTile(
                        title: "Duración",
                        value: formatElapsed(log.duration),
                        delta: prev.map { timeDelta(log.duration - $0.duration) },
                        good: nil
                    )
                    StatTile(
                        title: "Kilos totales",
                        value: "\(fmtThousands(log.volume)) kg",
                        delta: prev.map { signed(fmtThousands(abs(log.volume - $0.volume)), log.volume - $0.volume) + " kg" },
                        good: prev.map { log.volume >= $0.volume }
                    )
                    StatTile(
                        title: "Series",
                        value: "\(log.sets)",
                        delta: prev.map { signed("\(abs(log.sets - $0.sets))", Double(log.sets - $0.sets)) },
                        good: prev.map { log.sets >= $0.sets }
                    )
                    StatTile(
                        title: "Ejercicios",
                        value: "\(log.exercisesDone)/\(log.exercisesTotal)",
                        delta: nil,
                        good: nil
                    )
                }

                Group {
                    if let prev {
                        Text("Comparado con la vez anterior de este día (\(Dates.short(prev.start))). Kilos totales = peso × repeticiones.")
                    } else {
                        Text("Es la primera vez que registrás este día: la próxima vas a ver la comparación. Kilos totales = peso × repeticiones.")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)

                if !log.prs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Récords nuevos").eyebrow(12)
                        ForEach(log.prs, id: \.self) { pr in
                            HStack(spacing: 10) {
                                Image(systemName: "medal.fill")
                                    .foregroundStyle(Palette.gold)
                                Text(pr.name)
                                    .foregroundStyle(Palette.fg)
                                Spacer()
                                Text(pr.text ?? "\(fmtW(pr.weight)) kg")
                                    .font(.display(20, weight: .bold))
                                    .foregroundStyle(Palette.gold)
                                Text("antes \(pr.previousText ?? fmtW(pr.previous))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.muted)
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.gold.opacity(0.1)))
                        }
                    }
                }

                BigButton(title: "Listo") { dismiss() }
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func signed(_ text: String, _ value: Double) -> String {
        if value > 0 { return "+\(text)" }
        if value < 0 { return "−\(text)" }
        return "igual"
    }

    private func timeDelta(_ seconds: TimeInterval) -> String {
        if abs(seconds) < 30 { return "igual" }
        return signed(formatElapsed(abs(seconds)), seconds)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let delta: String?
    /// true = mejor que la vez anterior, false = peor, nil = neutro.
    let good: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).eyebrow(11)
            Text(value)
                .font(.display(30, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let delta {
                Text(delta)
                    .font(.display(14, weight: .semibold))
                    .foregroundStyle(deltaColor)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.surface2))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }

    private var deltaColor: Color {
        guard let good, delta != "igual" else { return Palette.muted }
        return good ? Palette.accent : Palette.warn
    }
}
