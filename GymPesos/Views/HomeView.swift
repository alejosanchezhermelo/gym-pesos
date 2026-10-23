import SwiftUI

enum HomeTab: String {
    case train, progress, history
}

/// Inicio con tres pestañas: Entrenar, Progreso e Historial.
struct HomeView: View {
    var openDay: (Int) -> Void
    var openSettings: () -> Void
    var openBodyWeight: () -> Void
    var openLog: (SessionLog) -> Void
    var addDay: () -> Void

    @AppStorage("homeTab") private var tab: HomeTab = .train
    private var store: Store { Store.shared }

    var body: some View {
        Group {
            switch tab {
            case .train:
                TrainTab(openDay: openDay, openSettings: openSettings, openBodyWeight: openBodyWeight,
                         addDay: addDay, showProgress: { tab = .progress })
            case .progress:
                ProgressTab(openBodyWeight: openBodyWeight, openLog: openLog)
            case .history:
                HistoryTab(openLog: openLog)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Dock {
                VStack(spacing: 10) {
                    if let s = store.session {
                        LiveButton(dayName: s.dayName, start: s.start) { openDay(s.dayIndex) }
                    }
                    TabBar(tab: $tab)
                }
            }
        }
    }
}

private struct TabBar: View {
    @Binding var tab: HomeTab

    var body: some View {
        HStack(spacing: 6) {
            item(.train, "Entrenar", "dumbbell.fill")
            item(.progress, "Progreso", "chart.line.uptrend.xyaxis")
            item(.history, "Historial", "clock.arrow.circlepath")
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.surface2))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line, lineWidth: 1))
    }

    private func item(_ t: HomeTab, _ title: String, _ icon: String) -> some View {
        let on = tab == t
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { tab = t }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                Text(title)
                    .font(.display(13, weight: .bold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(on ? Palette.accentInk : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 14).fill(on ? Palette.accent : Color.clear))
        }
        .buttonStyle(PressScale())
        .sensoryFeedback(.selection, trigger: on)
    }
}

// MARK: - Entrenar

private struct TrainTab: View {
    var openDay: (Int) -> Void
    var openSettings: () -> Void
    var openBodyWeight: () -> Void
    var addDay: () -> Void
    var showProgress: () -> Void

    private var store: Store { Store.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let d = store.suggestedDayIndex, store.routine.days.indices.contains(d) {
                    Button { openDay(d) } label: {
                        HStack(spacing: 8) {
                            Text("Te toca:")
                                .font(.system(size: 16))
                                .foregroundStyle(Palette.muted)
                            Text(store.routine.days[d].name)
                                .font(.display(22, weight: .bold))
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Palette.accent)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(PressScale())
                }

                HomeCards(openDay: openDay, openBodyWeight: openBodyWeight, showProgress: showProgress)

                if store.data.demo {
                    DemoBanner(clear: { store.clearDemo() })
                }

                VStack(spacing: 12) {
                    ForEach(Array(store.routine.days.enumerated()), id: \.element.id) { item in
                        DayCard(day: item.element, index: item.offset) { openDay(item.offset) }
                    }
                    Button(action: addDay) {
                        Label("Agregar día", systemImage: "plus")
                            .font(.display(17, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(SpanishDate.weekdayAndDay(Date())).eyebrow()
                (Text("Hola") + Text(store.data.userName.map { ", \($0)" } ?? "") + Text("!"))
                    .font(.display(40, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            DockIconButton(systemImage: "gearshape.fill", label: "Ajustes", action: openSettings)
        }
    }
}

private struct DemoBanner: View {
    let clear: () -> Void

    var body: some View {
        HStack {
            Text("Pesos anteriores de ejemplo")
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
            Spacer()
            Button("Borrar ejemplos", action: clear)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

private struct DayCard: View {
    let day: RoutineDay
    let index: Int
    let open: () -> Void

    private var store: Store { Store.shared }

    var body: some View {
        let done = day.exercises.filter { store.status($0).all }.count
        let fraction = day.exercises.isEmpty ? 0 : Double(done) / Double(day.exercises.count)
        let running = store.session?.dayIndex == index
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day.name)
                            .font(.display(34, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.fg)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        HStack(spacing: 4) {
                            Text(meta)
                                .foregroundStyle(Palette.muted)
                            if running {
                                Text("· en curso")
                                    .fontWeight(.bold)
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        .font(.system(size: 14))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Palette.accentInk)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Palette.accent))
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.surface2)
                        Capsule().fill(Palette.accent).frame(width: g.size.width * fraction)
                    }
                }
                .frame(height: 4)
                .animation(.easeOut(duration: 0.5), value: fraction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(running ? Palette.accent : Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressScale())
    }

    private var meta: String {
        var s = "\(day.exercises.count) ejercicios"
        if let last = store.lastDate(of: day) {
            s += last == Dates.key() ? " · hoy" : " · último \(Dates.short(last))"
        }
        return s
    }
}
