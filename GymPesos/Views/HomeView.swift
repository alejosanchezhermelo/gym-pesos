import SwiftUI

/// Inicio: "¿Qué toca hoy?" con un botón grande por día.
struct HomeView: View {
    var openDay: (Int) -> Void
    var openSettings: () -> Void

    private var store: Store { Store.shared }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer(minLength: 22)
                    if store.data.demo {
                        DemoBanner(clear: { store.clearDemo() })
                            .padding(.bottom, 16)
                    }
                    VStack(spacing: 12) {
                        ForEach(Array(store.routine.days.enumerated()), id: \.element.id) { item in
                            DayCard(day: item.element, index: item.offset) { openDay(item.offset) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Dock {
                if let s = store.session {
                    DockIconButton(systemImage: "gearshape.fill", label: "Ajustes", action: openSettings)
                    LiveButton(dayName: s.dayName, start: s.start) { openDay(s.dayIndex) }
                } else {
                    BigButton(title: "Ajustes", systemImage: "gearshape.fill", kind: .secondary, action: openSettings)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.routine.profe.isEmpty ? "Mi rutina" : "Rutina de \(store.routine.profe)").eyebrow()
            (Text("¿Qué\ntoca ") + Text("hoy").foregroundColor(Palette.accent) + Text("?"))
                .font(.display(40, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Palette.fg)
                .lineSpacing(-4)
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
