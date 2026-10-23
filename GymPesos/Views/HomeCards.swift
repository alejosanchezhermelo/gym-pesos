import SwiftUI

/// Tarjetas de colores que se deslizan de costado en el inicio, estilo widgets del iPhone.
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

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
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
            .scrollClipDisabled()
            .frame(height: 156)

            HStack(spacing: 6) {
                ForEach(Card.allCases) { card in
                    let on = (position ?? saved) == card.rawValue
                    Capsule()
                        .fill(on ? Palette.fg : Palette.line)
                        .frame(width: on ? 18 : 7, height: 7)
                        .animation(.spring(response: 0.3), value: on)
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

/// Colores de cada tarjeta.
private enum CardColors {
    static let ink = Color(hex: 0x111111)
    static var week: [Color] { [Palette.accent, Palette.accent.opacity(0.72)] }
    static let near = [Color(hex: 0xFF8A5C), Color(hex: 0xFF4F6D)]
    static let weight = [Color(hex: 0x6BE8FF), Color(hex: 0x2F9BFF)]
    static let record = [Color(hex: 0xFFDB6E), Color(hex: 0xF0A12B)]
    static let month = [Color(hex: 0xC69BFF), Color(hex: 0x8356FF)]
}

/// Marco de color con degradé, ícono grande de fondo y texto oscuro.
private struct ColorCard<Content: View>: View {
    let title: String
    let icon: String
    let colors: [Color]
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                Text(title)
                    .font(.display(14, weight: .heavy))
                    .tracking(1.6)
                    .textCase(.uppercase)
            }
            .foregroundStyle(CardColors.ink.opacity(0.75))
            content
            Spacer(minLength: 0)
        }
        .foregroundStyle(CardColors.ink)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .bottomTrailing) {
            Image(systemName: icon)
                .font(.system(size: 92, weight: .black))
                .foregroundStyle(CardColors.ink.opacity(0.1))
                .rotationEffect(.degrees(-12))
                .offset(x: 14, y: 18)
        }
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: (colors.first ?? .clear).opacity(0.35), radius: 14, y: 6)
    }
}

private struct Hint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(CardColors.ink.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Big: View {
    let text: String
    var size: CGFloat = 46
    var body: some View {
        Text(text)
            .font(.display(size, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

private struct Small: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(CardColors.ink.opacity(0.78))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct WeekCard: View {
    private var store: Store { Store.shared }

    var body: some View {
        let w = store.weekInfo()
        ColorCard(title: "Esta semana", icon: "flame.fill", colors: CardColors.week) {
            HStack(alignment: .center, spacing: 12) {
                Big(text: "\(w.done)/\(w.goal)")
                HStack(spacing: 5) {
                    ForEach(0..<w.goal, id: \.self) { i in
                        Circle()
                            .fill(i < w.done ? CardColors.ink : CardColors.ink.opacity(0.15))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            if w.streak > 0 {
                Small(text: "🔥 \(w.streak) semana\(w.streak == 1 ? "" : "s") seguida\(w.streak == 1 ? "" : "s") cumpliendo")
            } else if w.done >= w.goal {
                Small(text: "¡Objetivo cumplido!")
            } else {
                Small(text: "Te falta\(w.goal - w.done == 1 ? "" : "n") \(w.goal - w.done) para tu objetivo")
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
                ColorCard(title: "Cerca de un récord", icon: "target", colors: CardColors.near) {
                    Big(text: near.text.replacingOccurrences(of: "Te faltan ", with: "−").replacingOccurrences(of: "Te falta ", with: "−"), size: 40)
                    Small(text: near.name)
                    Small(text: "Récord: \(near.record)")
                }
            }
            .buttonStyle(PressScale())
        } else {
            ColorCard(title: "Cerca de un récord", icon: "target", colors: CardColors.near) {
                Hint(text: "Cuando hayas hecho un ejercicio un par de veces, acá te digo cuánto te falta para tu récord.")
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
            ColorCard(title: "Peso corporal", icon: "scalemass.fill", colors: CardColors.weight) {
                if let last = list.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Big(text: fmtW(last.kg))
                        Text("kg").font(.display(20, weight: .heavy))
                        if list.count >= 2 {
                            let diff = last.kg - list[list.count - 2].kg
                            Text("\(diff >= 0 ? "▲" : "▼") \(fmtW(abs(diff)))")
                                .font(.display(17, weight: .heavy))
                                .foregroundStyle(CardColors.ink.opacity(0.7))
                                .padding(.leading, 6)
                        }
                    }
                    Small(text: "\(relativeDay(last.date).capitalized(with: Locale(identifier: "es_AR"))) · tocá para actualizar")
                } else {
                    Big(text: "— kg", size: 40)
                    Small(text: "Tocá para cargar tu peso")
                }
            }
        }
        .buttonStyle(PressScale())
    }
}

private struct LastRecordCard: View {
    private var store: Store { Store.shared }

    var body: some View {
        ColorCard(title: "Último récord", icon: "medal.fill", colors: CardColors.record) {
            if let last = store.lastRecord() {
                Big(text: last.pr.text ?? "\(fmtW(last.pr.weight)) kg", size: 38)
                Small(text: last.pr.name)
                Small(text: relativeDay(last.date).capitalized(with: Locale(identifier: "es_AR")))
            } else {
                Hint(text: "Todavía no hay récords. ¡El primero puede ser hoy!")
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
            ColorCard(title: "Este mes", icon: "calendar", colors: CardColors.month) {
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    stat("\(m?.days ?? 0)", "días")
                    stat(fmtThousands(m?.volume ?? 0), "kg")
                    stat("\(m?.records ?? 0)", "récords")
                }
                Small(text: "Ver progreso ›")
            }
        }
        .buttonStyle(PressScale())
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            Big(text: value, size: 34)
            Text(label)
                .font(.display(13, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(CardColors.ink.opacity(0.7))
        }
    }
}
