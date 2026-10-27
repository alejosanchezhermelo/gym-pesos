import SwiftUI
import UIKit

/// Editar un día: nombre, ejercicios (agregar, cambiar, reordenar, borrar) y borrar el día.
struct DayEditorSheet: View {
    let dayIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var day = RoutineDay(name: "", exercises: [])
    @State private var moves: [String: String] = [:]
    @State private var loaded = false
    @State private var editing: EditTarget?
    @State private var pendingDelete: IndexSet?
    @State private var deleteDayArmed = false
    @State private var confirmDeleteDay = false

    private var store: Store { Store.shared }

    struct EditTarget: Identifiable {
        let id = UUID()
        /// nil = ejercicio nuevo.
        let index: Int?
        let exercise: RoutineExercise
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text("Editar día")
                    .font(.display(18, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)
                Spacer()
                Button("Listo") { save() }
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.accent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            List {
                Section {
                    TextField("Nombre del día", text: $day.name)
                        .font(.display(26, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.fg)
                        .listRowBackground(Palette.surface2)
                } header: {
                    Text("Nombre del día").eyebrow(12)
                }

                Section {
                    ForEach(Array(day.exercises.enumerated()), id: \.element.id) { item in
                        Button {
                            editing = EditTarget(index: item.offset, exercise: item.element)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.element.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Palette.fg)
                                    Text("\(item.element.series) × \(item.element.reps)\(item.element.isBodyweight ? " · sin peso" : "")")
                                        .font(.display(14, weight: .semibold))
                                        .foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Image(systemName: "pencil")
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        .listRowBackground(Palette.surface2)
                    }
                    .onMove { from, to in day.exercises.move(fromOffsets: from, toOffset: to) }
                    .onDelete { pendingDelete = $0 }

                    Button {
                        editing = EditTarget(index: nil, exercise: RoutineExercise(name: "", series: 3, reps: "12"))
                    } label: {
                        Label("Agregar ejercicio", systemImage: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    .listRowBackground(Palette.surface2)
                } header: {
                    Text("Ejercicios · arrastrá ☰ para ordenar").eyebrow(12)
                } footer: {
                    Text("Borrar un ejercicio de la rutina no borra su historial: si lo volvés a agregar con el mismo nombre, recupera sus pesos y récords.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }

                if store.routine.days.count > 1 {
                    Section {
                        Button {
                            if deleteDayArmed {
                                confirmDeleteDay = true
                            } else {
                                deleteDayArmed = true
                                Task {
                                    try? await Task.sleep(for: .seconds(3))
                                    deleteDayArmed = false
                                }
                            }
                        } label: {
                            Label(deleteDayArmed ? "¿Seguro? Tocá de nuevo" : "Borrar este día", systemImage: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(deleteDayArmed ? Palette.accentInk : Palette.warn)
                        }
                        .listRowBackground(deleteDayArmed ? Palette.warn : Palette.surface2)
                    } footer: {
                        Text("El historial de los ejercicios queda guardado.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .tint(Palette.accent)
        }
        .onAppear(perform: load)
        .sheet(item: $editing) { target in
            ExerciseEditorSheet(exercise: target.exercise, isNew: target.index == nil) { ex, move in
                if let move { moves[move.0] = move.1 }
                if let i = target.index, day.exercises.indices.contains(i) {
                    day.exercises[i] = ex
                } else {
                    day.exercises.append(ex)
                }
            }
            .presentationBackground(Palette.surface)
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .alert("¿Quitar este ejercicio del día?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Quitar", role: .destructive) {
                if let set = pendingDelete { day.exercises.remove(atOffsets: set) }
                pendingDelete = nil
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Su historial no se borra.")
        }
        .alert("¿Borrar \(day.name)?", isPresented: $confirmDeleteDay) {
            Button("Borrar día", role: .destructive) {
                store.deleteDay(dayIndex)
                dismiss()
            }
            Button("Cancelar", role: .cancel) { deleteDayArmed = false }
        } message: {
            Text("Se quita el día de la rutina. No se puede deshacer.")
        }
    }

    private func load() {
        guard !loaded, store.routine.days.indices.contains(dayIndex) else { return }
        day = store.routine.days[dayIndex]
        loaded = true
    }

    private func save() {
        store.saveDay(dayIndex, day, moves: moves)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// Editar o crear un ejercicio.
struct ExerciseEditorSheet: View {
    let original: RoutineExercise
    let isNew: Bool
    let onSave: (RoutineExercise, (String, String)?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var series: Int
    @State private var reps: String
    @State private var bodyweight: Bool
    @State private var figure: String?
    @State private var pickingFigure = false
    @State private var askMove = false
    @State private var resetArmed = false
    @State private var confirmReset = false

    private var store: Store { Store.shared }

    init(exercise: RoutineExercise, isNew: Bool, onSave: @escaping (RoutineExercise, (String, String)?) -> Void) {
        original = exercise
        self.isNew = isNew
        self.onSave = onSave
        _name = State(initialValue: exercise.name)
        _series = State(initialValue: exercise.series)
        _reps = State(initialValue: exercise.reps)
        _bodyweight = State(initialValue: isNew ? false : exercise.isBodyweight)
        _figure = State(initialValue: exercise.figure)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(isNew ? "Nuevo ejercicio" : "Editar ejercicio")
                    .font(.display(32, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)

                field("Nombre") {
                    TextField("Ej: Press plano barra", text: $name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.fg)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.bg))
                        .onChange(of: name) { _, new in
                            if isNew { bodyweight = looksBodyweight(new) }
                        }
                }

                field("Series") {
                    HStack(spacing: 12) {
                        roundKey("minus") { series = max(1, series - 1) }
                        Text("\(series)")
                            .font(.display(40, weight: .bold))
                            .foregroundStyle(Palette.fg)
                            .frame(minWidth: 60)
                        roundKey("plus") { series = min(12, series + 1) }
                    }
                }

                field("Reps") {
                    TextField("12, 10-12 o 12-10-8", text: $reps)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.fg)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.bg))
                }

                Toggle(isOn: $bodyweight) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sin peso")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.fg)
                        Text("Con el peso del cuerpo: cuentan solo las reps.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                    }
                }
                .tint(Palette.accent)

                field("Dibujo") {
                    Button { pickingFigure = true } label: {
                        HStack(spacing: 12) {
                            ExerciseFigure(name: trimmedName, figure: figure, caption: false)
                                .frame(width: 96, height: 70)
                                .allowsHitTesting(false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(figure.flatMap(Motions.title(of:)) ?? "Automático")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Palette.fg)
                                Text(figure == nil ? "Se elige solo por el nombre. Tocá para cambiarlo." : "Elegido a mano. Tocá para cambiarlo.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.muted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Palette.muted)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.bg))
                    }
                    .buttonStyle(PressScale())
                }

                BigButton(title: isNew ? "Agregar" : "Guardar") { trySave() }
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.4 : 1)

                if !isNew && store.hasHistory(original.name) {
                    Button {
                        if resetArmed { confirmReset = true } else {
                            resetArmed = true
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                resetArmed = false
                            }
                        }
                    } label: {
                        Label(resetArmed ? "¿Seguro? Tocá de nuevo" : "Reiniciar este ejercicio", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(resetArmed ? Palette.accentInk : Palette.warn)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 14).fill(resetArmed ? Palette.warn : Palette.surface2))
                    }
                    .buttonStyle(PressScale())
                    Text("Borra los pesos, reps y récords de este ejercicio. El ejercicio sigue en la rutina.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $pickingFigure) {
            FigurePickerSheet(name: trimmedName, selection: $figure)
                .presentationBackground(Palette.surface)
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .alert("¿Pasar el historial al nombre nuevo?", isPresented: $askMove) {
            Button("Pasar historial") { finish(move: (exerciseKey(original.name), exerciseKey(trimmedName))) }
            Button("Empezar de cero") { finish(move: nil) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("\"\(original.name)\" tiene pesos y récords guardados. Si los pasás, \"\(trimmedName)\" sigue desde ahí.")
        }
        .alert("¿Reiniciar \(original.name)?", isPresented: $confirmReset) {
            Button("Reiniciar", role: .destructive) {
                store.resetExercise(original.name)
                resetArmed = false
            }
            Button("Cancelar", role: .cancel) { resetArmed = false }
        } message: {
            Text("Se borran sus pesos, reps y récords. No se puede deshacer.")
        }
    }

    private func trySave() {
        let renamed = !isNew && exerciseKey(trimmedName) != exerciseKey(original.name)
        if renamed && store.hasHistory(original.name) {
            askMove = true
        } else {
            finish(move: nil)
        }
    }

    private func finish(move: (String, String)?) {
        var ex = original
        ex.name = trimmedName
        ex.series = series
        ex.reps = reps.trimmingCharacters(in: .whitespaces).isEmpty ? "12" : reps.trimmingCharacters(in: .whitespaces)
        ex.bodyweight = bodyweight
        ex.figure = figure
        onSave(ex, move)
        dismiss()
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrow(12)
            content()
        }
    }

    private func roundKey(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Palette.fg)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Palette.surface2))
        }
        .buttonStyle(PressScale())
    }
}

/// Elegir a mano el dibujo de un ejercicio, con todos los muñequitos animados.
struct FigurePickerSheet: View {
    let name: String
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Elegí el dibujo")
                    .font(.display(32, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.fg)

                LazyVGrid(columns: columns, spacing: 10) {
                    cell(id: nil, title: "Automático", subtitle: "Por el nombre")
                }

                ForEach(Motions.catalog, id: \.name) { group in
                    Text(group.name).eyebrow(12)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(group.items, id: \.id) { item in
                            cell(id: item.id, title: item.title, subtitle: nil)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
    }

    private func cell(id: String?, title: String, subtitle: String?) -> some View {
        let selected = selection == id
        return Button {
            selection = id
            UISelectionFeedbackGenerator().selectionChanged()
            dismiss()
        } label: {
            VStack(spacing: 6) {
                ExerciseFigure(name: id == nil ? name : "", figure: id, caption: false)
                    .frame(height: 96)
                    .allowsHitTesting(false)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Palette.accent : Palette.fg)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 34)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.surface2))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Palette.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(PressScale())
    }
}
