import SwiftUI
import UIKit
import UserNotifications

/// Ajustes: salto de peso, avisos al reloj y reiniciar estadísticas.
struct SettingsSheet: View {
    var openImport: () -> Void = {}

    @State private var name = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var armed: ResetTarget?
    @State private var disarmTask: Task<Void, Never>?
    @State private var confirming: ResetTarget?
    @State private var notifications: UNAuthorizationStatus?
    @State private var testSent = false

    private var store: Store { Store.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Ajustes")
                    .font(.display(40, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)

                section("Tus datos") {
                    TextField("Tu nombre (para el saludo)", text: $name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.fg)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface2))
                        .onAppear { name = store.data.userName ?? "" }
                        .onSubmit { store.setUserName(name) }
                        .onChange(of: name) { _, new in store.setUserName(new) }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Objetivo semanal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.fg)
                            Text("Entrenamientos por semana")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button { store.setWeeklyGoal(store.weeklyGoal - 1) } label: {
                            Image(systemName: "minus").frame(width: 40, height: 40).background(Circle().fill(Palette.surface2))
                        }
                        .buttonStyle(PressScale())
                        Text("\(store.weeklyGoal)")
                            .font(.display(28, weight: .bold))
                            .frame(minWidth: 30)
                        Button { store.setWeeklyGoal(store.weeklyGoal + 1) } label: {
                            Image(systemName: "plus").frame(width: 40, height: 40).background(Circle().fill(Palette.surface2))
                        }
                        .buttonStyle(PressScale())
                    }
                    .foregroundStyle(Palette.fg)
                }

                section("Rutina") {
                    BigButton(title: "Importar rutina nueva", systemImage: "square.and.arrow.down", kind: .secondary, action: openImport)
                    note("Para cambiar ejercicios, series o reps sin importar de nuevo, entrá a un día y tocá Editar.")
                }

                section("Salto de peso") {
                    HStack(spacing: 8) {
                        ForEach([1.0, 2.5, 5.0], id: \.self) { s in
                            let on = store.data.step == s
                            Button { store.setStep(s) } label: {
                                Text("\(fmtW(s)) kg")
                                    .font(.display(18, weight: .bold))
                                    .foregroundStyle(on ? Palette.accentInk : Palette.fg)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(on ? Palette.accent : Palette.surface2))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Palette.accent : Palette.line, lineWidth: 1))
                            }
                            .buttonStyle(PressScale())
                        }
                    }
                    note("Lo usan los botones + y − de la app y de la pantalla de bloqueo.")
                }

                section("Avisos de récord") {
                    notificationsBlock
                }

                section("Estadísticas") {
                    VStack(spacing: 8) {
                        if store.data.demo {
                            resetRow(.demo)
                        }
                        ForEach(Array(store.routine.days.enumerated()), id: \.element.id) { item in
                            resetRow(.day(item.offset, item.element.name))
                        }
                        resetRow(.all)
                    }
                    note("Doble confirmación: primer toque arma el botón, segundo toque pide confirmar. La rutina no se borra.")
                }

                BigButton(title: "Listo") { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .task { notifications = await Notifier.status() }
        .alert(
            confirming?.alertTitle ?? "",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            presenting: confirming
        ) { target in
            Button(target.confirmTitle, role: .destructive) { perform(target) }
            Button("Cancelar", role: .cancel) {}
        } message: { target in
            Text(target.message)
        }
    }

    // MARK: Avisos

    @ViewBuilder
    private var notificationsBlock: some View {
        switch notifications {
        case .authorized, .provisional, .ephemeral:
            note("Activados. Si marcás un récord desde la pantalla de bloqueo, te llega un aviso y, con el iPhone bloqueado, vibra el Apple Watch.")
            BigButton(title: testSent ? "Bloqueá el celular…" : "Probar aviso en 5 s", systemImage: "applewatch", kind: .secondary) {
                testSent = true
                Task {
                    await Notifier.test()
                    try? await Task.sleep(for: .seconds(6))
                    testSent = false
                }
            }
        case .denied:
            note("Están desactivados. Activalos en Ajustes del iPhone → Gym Pesos → Notificaciones.")
            BigButton(title: "Abrir Ajustes del iPhone", systemImage: "gear", kind: .secondary) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        default:
            note("Para que el reloj vibre con un récord nuevo, la app necesita permiso para avisarte.")
            BigButton(title: "Activar avisos", systemImage: "bell.fill", kind: .secondary) {
                Task {
                    _ = await Notifier.requestPermission()
                    notifications = await Notifier.status()
                }
            }
        }
    }

    // MARK: Reiniciar

    private func resetRow(_ target: ResetTarget) -> some View {
        let isArmed = armed == target
        return Button {
            if isArmed {
                disarmTask?.cancel()
                armed = nil
                confirming = target
            } else {
                armed = target
                disarmTask?.cancel()
                disarmTask = Task {
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled { armed = nil }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isArmed ? "¿Seguro? Tocá de nuevo" : target.rowTitle)
                        .font(.system(size: 16, weight: .semibold))
                    Text(target.rowDetail)
                        .font(.system(size: 13))
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: target.isAll ? "trash.fill" : "arrow.counterclockwise")
            }
            .foregroundStyle(isArmed ? Palette.accentInk : (target.isAll ? Palette.warn : Palette.fg))
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(isArmed ? Palette.warn : Palette.surface2))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isArmed ? Palette.warn : Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressScale())
        .animation(.easeOut(duration: 0.2), value: isArmed)
        .sensoryFeedback(.warning, trigger: isArmed) { _, new in new }
    }

    private func perform(_ target: ResetTarget) {
        switch target {
        case .demo: store.clearDemo()
        case .day(let i, _): store.resetDay(i)
        case .all: store.resetAll()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Piezas

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrow()
            content()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

enum ResetTarget: Hashable {
    case demo
    case day(Int, String)
    case all

    var isAll: Bool { self == .all }

    var rowTitle: String {
        switch self {
        case .demo: "Borrar pesos de ejemplo"
        case .day(_, let name): "Reiniciar \(name)"
        case .all: "Borrar todo el historial"
        }
    }

    var rowDetail: String {
        switch self {
        case .demo: "Quedan solo los pesos que cargaste vos."
        case .day: "Pesos, récords y entrenamientos de este día."
        case .all: "Todos los días, récords y entrenamientos."
        }
    }

    var alertTitle: String {
        switch self {
        case .demo: "¿Borrar los pesos de ejemplo?"
        case .day(_, let name): "¿Reiniciar \(name)?"
        case .all: "¿Borrar todo el historial?"
        }
    }

    var message: String {
        switch self {
        case .demo: "Se borran los pesos inventados de la maqueta. Lo tuyo queda."
        case .day: "Se borran los pesos, récords y entrenamientos anotados en este día. No se puede deshacer."
        case .all: "Se borran todos los pesos, récords y entrenamientos. La rutina queda. No se puede deshacer."
        }
    }

    var confirmTitle: String {
        switch self {
        case .demo: "Borrar ejemplos"
        case .day: "Reiniciar"
        case .all: "Borrar todo"
        }
    }
}
