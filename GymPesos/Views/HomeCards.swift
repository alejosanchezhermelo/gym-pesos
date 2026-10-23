import SwiftUI

/// Tarjetas que se deslizan de costado en el inicio.
struct HomeCards: View {
    var openDay: (Int) -> Void
    var openBodyWeight: () -> Void
    var showProgress: () -> Void

    enum Card: String, CaseIterable, Identifiable {
        case week, near, weight, record, month
        var id: String { rawValue }
    }

    @AppStorage("homeCard") private var saved: String = Card.week.rawValue
    @State private var position: String?

    private var store: Store { Store.shared }

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(Card.allCases) { card in
                        cardView(card)
                            .containerRelativeFrame(.horizontal)
                            .id(card.rawValue)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)
            .scrollIndicators(.hidden)
            .frame(height: 140)

            HStack(spacing: 6) {
                ForEach(Card.allCases) { card in
                    Circle()
                        .fill((position ?? saved) == card.rawValue ? Palette.accent : Palette.line)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { position = saved }
        .onChange(of: position) { _, new in
            if let new { saved = new }
        }
        .sensoryFeedback(.selection, trigger: position)
    }

    @ViewBuilder
    private func cardView(_ card: Card) -> some View {
        switch card {
        case .week: WeekCard()
        case .near: NearRecordCard(openDay: openDay)
        case .weight: BodyWeightCard(openBodyWeight: openBodyWeight)
        case .record: LastRecordCard()
        case .month: MonthCard(showProgress: showProgress)
        }
    }
}

/// Marco común de las tarjetas.
private struct CardBox<Content: View>: View {
    let title: String
    var gold = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrow(12)
            content
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(gold ? Palette.gold.opacity(0.1) : Palette.surface)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(gold ? Palette.gold.opacity(0.6) : Palette.line, lineWidth: 1))
    }
}

private struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct WeekCard: View {
    private var store: Store { Store.shared }

    var body: some View {
        let w = store.weekInfo()
        CardBox(title: "Esta semana") {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(0..<w.goal, id: \.self) { i in
                        Circle()
                            .fill(i < w.done ? Palette.accent : Palette.surface2)
                            .overlay(Circle().stroke(i < w.done ? Palette.accent : Palette.line, lineWidth: 1.5))
                            .frame(width: 18, height: 18)
                    }
                }
                Text("\(w.done) de \(w.goal)")
                    .font(.display(30, weight: .bold))
                    .foregroundStyle(w.done >= w.goal ? Palette.accent : Palette.fg)
            }
            if w.streak > 0 {
                Text("🔥 \(w.streak) semana\(w.streak == 1 ? "" : "s") seguida\(w.streak == 1 ? "" : "s") cumpliendo tu objetivo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.warn)
            } else {
                Text(w.done >= w.goal ? "¡Objetivo cumplido!" : "Te falta\(w.goal - w.done == 1 ? "" : "n") \(w.goal - w.done) para tu objetivo")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

private struct NearRecordCard: View {
    var openDay: (Int) -> Void
    private var store: Store { Store.shared }

    var body: some View {
        if let near = store.nearRecord() {
            Button { openDay(near.dayIndex) } label: {
                CardBox(title: "Cerca de un récord") {
                    Text(near.name)
                        .font(.display(22, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(near.text)
                        .font(.display(20, weight: .bold))
                        .foregroundStyle(Palette.accent)
                    Label("Récord: \(near.record)", systemImage: "medal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                }
            }
            .buttonStyle(PressScale())
        } else {
            CardBox(title: "Cerca de un récord") {
                EmptyHint(text: "Cuando hayas hecho un ejercicio un par de veces, acá te digo cuánto te falta para tu récord.")
            }
        }
    }
}

private struct BodyWeightCard: View {
    var openBodyWeight: () -> Void
    private var store: Store { Store.shared }

    var body: some View {
        let list = store.data.bodyWeights ?? []
        Button(action: openBodyWeight) {
            CardBox(title: "Peso corporal") {
                if let last = list.last {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            (Text(fmtW(last.kg)).font(.display(36, weight: .bold))
                                + Text(" kg").font(.display(16, weight: .semibold)).foregroundColor(Palette.muted))
                                .foregroundStyle(Palette.fg)
                            Text(relativeDay(last.date).capitalized(with: Locale(identifier: "es_AR")))
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        if list.count >= 2 {
                            Sparkline(points: list.suffix(10).map { ProgressPoint(date: Dates.key($0.date), weight: $0.kg) })
                                .frame(width: 90, height: 34)
                        }
                    }
                    Text("Tocá para actualizar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                } else {
                    EmptyHint(text: "Cargá tu peso para ver tu evolución y cuánto levantás en relación a tu peso.")
                    Text("Cargar peso")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .buttonStyle(PressScale())
    }
}

private struct LastRecordCard: View {
    private var store: Store { Store.shared }

    var body: some View {
        if let last = store.lastRecord() {
            CardBox(title: "Último récord", gold: true) {
                HStack(spacing: 8) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(last.pr.name)
                            .font(.display(20, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(last.pr.text ?? "\(fmtW(last.pr.weight)) kg")
                            .font(.display(22, weight: .bold))
                            .foregroundStyle(Palette.gold)
                    }
                }
                Text(relativeDay(last.date).capitalized(with: Locale(identifier: "es_AR")))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
        } else {
            CardBox(title: "Último récord", gold: true) {
                EmptyHint(text: "Todavía no hay récords. ¡El primero puede ser hoy!")
            }
        }
    }
}

private struct MonthCard: View {
    var showProgress: () -> Void
    private var store: Store { Store.shared }

    var body: some View {
        let m = store.monthStats(offset: 0)
        Button(action: showProgress) {
            CardBox(title: "Este mes") {
                HStack(spacing: 18) {
                    stat("\(m?.days ?? 0)", "días")
                    stat(fmtThousands(m?.volume ?? 0), "kg")
                    stat("\(m?.records ?? 0)", "récords")
                }
                Text("Ver progreso ›")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            }
        }
        .buttonStyle(PressScale())
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.display(30, weight: .bold))
                .foregroundStyle(Palette.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.display(12, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Palette.muted)
        }
    }
}
