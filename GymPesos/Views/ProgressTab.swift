import Charts
import SwiftUI

/// Pestaña Progreso: resumen del mes, calendario, récords y peso corporal.
struct ProgressTab: View {
    var openBodyWeight: () -> Void
    var openLog: (SessionLog) -> Void

    @State private var offset = 0
    private var store: Store { Store.shared }

    var body: some View {
        let month = store.monthStats(offset: offset)
        let previous = store.monthStats(offset: offset - 1)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Progreso")
                    .font(.display(40, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)

                HStack {
                    arrow("chevron.left") { offset -= 1 }
                    Spacer()
                    Text(month.map { SpanishDate.monthAndYear($0.interval.start) } ?? "")
                        .font(.display(24, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.fg)
                    Spacer()
                    arrow("chevron.right") { offset += 1 }
                        .opacity(offset < 0 ? 1 : 0.3)
                        .disabled(offset >= 0)
                }

                if let month {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        tile("Días", "\(month.days)", previous.map { delta(Double(month.days - $0.days), unit: "") })
                        tile("Kilos", fmtThousands(month.volume), previous.map { percent(month.volume, $0.volume) })
                        tile("Récords", "\(month.records)", previous.map { delta(Double(month.records - $0.records), unit: "") })
                    }
                    if previous != nil {
                        Text("Comparado con el mes anterior.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }

                    MonthCalendar(interval: month.interval, trained: store.trainedDates(in: month.interval))

                    let records = month.logs.flatMap { log in log.prs.map { (log, $0) } }
                    if !records.isEmpty {
                        section("Récords del mes") {
                            ForEach(Array(records.enumerated()), id: \.offset) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: "medal.fill").foregroundStyle(Palette.gold)
                                    Text(item.element.1.name)
                                        .foregroundStyle(Palette.fg)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.element.1.text ?? "\(fmtW(item.element.1.weight)) kg")
                                        .font(.display(17, weight: .bold))
                                        .foregroundStyle(Palette.gold)
                                    Text(Dates.short(item.element.0.start))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.muted)
                                }
                                .font(.system(size: 15, weight: .semibold))
                            }
                        }
                    }

                    let byDay = Dictionary(grouping: month.logs, by: \.dayName)
                    if !byDay.isEmpty {
                        section("Por día de la rutina") {
                            ForEach(byDay.keys.sorted(), id: \.self) { name in
                                let logs = byDay[name] ?? []
                                HStack {
                                    Text(name)
                                        .foregroundStyle(Palette.fg)
                                    Spacer()
                                    Text("\(logs.count) \(logs.count == 1 ? "vez" : "veces") · \(fmtThousands(logs.reduce(0) { $0 + $1.volume })) kg")
                                        .foregroundStyle(Palette.muted)
                                }
                                .font(.system(size: 15))
                            }
                        }
                    }

                    if month.logs.isEmpty {
                        Text("Este mes todavía no hay entrenamientos.")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.muted)
                    }
                }

                section("Peso corporal") {
                    BodyWeightChart(list: store.data.bodyWeights ?? [])
                    BigButton(title: "Actualizar peso", systemImage: "scalemass.fill", kind: .secondary, action: openBodyWeight)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .animation(.easeOut(duration: 0.2), value: offset)
    }

    private func arrow(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.fg)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.surface2))
        }
        .buttonStyle(PressScale())
    }

    private func tile(_ title: String, _ value: String, _ delta: (String, Bool?)?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).eyebrow(11)
            Text(value)
                .font(.display(28, weight: .bold))
                .foregroundStyle(Palette.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let delta {
                Text(delta.0)
                    .font(.display(13, weight: .semibold))
                    .foregroundStyle(delta.1 == nil ? Palette.muted : (delta.1! ? Palette.accent : Palette.warn))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.surface2))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }

    private func delta(_ d: Double, unit: String) -> (String, Bool?) {
        if d == 0 { return ("igual", nil) }
        return ((d > 0 ? "+" : "−") + "\(Int(abs(d)))\(unit)", d > 0)
    }

    private func percent(_ now: Double, _ before: Double) -> (String, Bool?) {
        guard before > 0 else { return (now > 0 ? "nuevo" : "igual", now > 0 ? true : nil) }
        let p = Int(((now - before) / before * 100).rounded())
        if p == 0 { return ("igual", nil) }
        return ((p > 0 ? "+" : "−") + "\(abs(p))%", p > 0)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrow(12)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }
}

/// Calendario del mes: en verde los días que entrenaste.
private struct MonthCalendar: View {
    let interval: DateInterval
    let trained: Set<String>

    var body: some View {
        let cal = Store.calendar
        let first = interval.start
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = (cal.component(.weekday, from: first) + 5) % 7
        let today = Dates.key()
        let cells: [Date?] = Array(repeating: nil, count: lead) + (0..<count).map { cal.date(byAdding: .day, value: $0, to: first) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(["L", "M", "M", "J", "V", "S", "D"].enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(.display(12, weight: .bold))
                        .foregroundStyle(Palette.muted)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { item in
                    if let date = item.element {
                        let key = Dates.key(date)
                        let on = trained.contains(key)
                        Text("\(cal.component(.day, from: date))")
                            .font(.display(15, weight: .bold))
                            .foregroundStyle(on ? Palette.accentInk : Palette.fg)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(RoundedRectangle(cornerRadius: 9).fill(on ? Palette.accent : Palette.surface2))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(key == today ? Palette.accent : Color.clear, lineWidth: 1.5))
                    } else {
                        Color.clear.frame(minHeight: 34)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }
}

private struct BodyWeightChart: View {
    let list: [BodyWeight]

    var body: some View {
        if list.count >= 2 {
            let values = list.map(\.kg)
            let lo = (values.min() ?? 0) - 1
            let hi = (values.max() ?? 1) + 1
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(fmtW(list.last!.kg)) kg")
                        .font(.display(28, weight: .bold))
                        .foregroundStyle(Palette.fg)
                    let diff = list.last!.kg - list.first!.kg
                    Text("\(diff >= 0 ? "+" : "−")\(fmtW(abs(diff))) kg desde \(Dates.short(list.first!.date))")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                }
                Chart(list) { w in
                    LineMark(x: .value("Fecha", w.date), y: .value("Kg", w.kg))
                        .foregroundStyle(Palette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("Fecha", w.date), y: .value("Kg", w.kg))
                        .foregroundStyle(Palette.accent)
                        .symbolSize(25)
                }
                .chartYScale(domain: lo...hi)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 110)
            }
        } else if let one = list.first {
            Text("\(fmtW(one.kg)) kg · \(Dates.short(one.date)). Cargalo de vez en cuando para ver el gráfico.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        } else {
            Text("Todavía no cargaste tu peso.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        }
    }
}
