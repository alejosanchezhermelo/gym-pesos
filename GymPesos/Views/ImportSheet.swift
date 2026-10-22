import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Importar la planilla del profe: PDF, Excel, CSV o texto pegado.
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var pasted = ""
    @State private var showPaste = false
    @State private var message: String?
    @State private var isError = false
    @State private var parsed: ImportedRoutine?

    private var store: Store { Store.shared }

    private static let types: [UTType] = {
        var t: [UTType] = [.pdf, .commaSeparatedText, .plainText]
        if let xlsx = UTType("org.openxmlformats.spreadsheetml.sheet") { t.append(xlsx) }
        if let xls = UTType("com.microsoft.excel.xls") { t.append(xls) }
        return t
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Planilla del profe").eyebrow()
                    Text("Importar rutina")
                        .font(.display(40, weight: .heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.fg)
                    Text("Elegí la planilla \"Armar rutina\" en PDF, Excel o CSV. Los días se arman solos con el nombre de cada día. Los pesos anteriores no se pierden: se guardan por nombre de ejercicio.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button { picking = true } label: {
                    VStack(spacing: 6) {
                        Text("Elegir archivo")
                            .font(.display(24, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.accent)
                        Text(".pdf · .xlsx · .csv")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Palette.surface2))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                }
                .buttonStyle(PressScale())

                DisclosureGroup(isExpanded: $showPaste) {
                    VStack(spacing: 10) {
                        TextEditor(text: $pasted)
                            .font(.system(size: 14, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(Palette.fg)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.bg))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
                        Text("Ejemplo:\nDÍA 1  Pecho y Bíceps\n1  Press plano barra  3  12")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        BigButton(title: "Leer texto", kind: .secondary) {
                            handle(pasted.components(separatedBy: .newlines))
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("O pegar el texto de la planilla")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.fg)
                }
                .tint(Palette.muted)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.surface2))

                if let message {
                    Text(message)
                        .font(.system(size: 15))
                        .foregroundStyle(isError ? Palette.warn : Palette.fg)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface2))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isError ? Palette.warn : Color.clear, lineWidth: 1))
                }

                if parsed != nil {
                    preview
                    BigButton(title: "Usar esta rutina") { apply() }
                }

                BigButton(title: "Cancelar", kind: .secondary) { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .fileImporter(isPresented: $picking, allowedContentTypes: Self.types) { result in
            switch result {
            case .success(let url): load(url)
            case .failure(let error): show(error.localizedDescription, error: true)
            }
        }
    }

    // MARK: Vista previa editable

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Binding(get: { parsed?.days ?? [] }, set: { parsed?.days = $0 })) { $day in
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Nombre del día", text: $day.name)
                        .font(.display(24, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.fg)
                        .padding(.bottom, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Palette.line).frame(height: 1)
                        }
                    ForEach($day.exercises) { $ex in
                        HStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Text(ex.name)
                                    .foregroundStyle(Palette.fg)
                                if !store.entries(exerciseKey(ex.name)).isEmpty {
                                    Text("con historial")
                                        .font(.display(11, weight: .semibold))
                                        .textCase(.uppercase)
                                        .foregroundStyle(Palette.accent)
                                }
                            }
                            Spacer(minLength: 4)
                            Text("\(ex.series) ×")
                                .foregroundStyle(Palette.muted)
                            TextField("reps", text: $ex.reps)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Palette.fg)
                                .frame(width: 64)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.bg))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ex.warn ? Palette.warn : Palette.line, lineWidth: 1))
                                .onChange(of: ex.reps) { _, _ in ex.warn = false }
                        }
                        .font(.system(size: 15))
                        .padding(.vertical, 8)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Palette.line).frame(height: 1)
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface2))
            }
        }
    }

    // MARK: Acciones

    private func load(_ url: URL) {
        show("Leyendo \(url.lastPathComponent)…", error: false)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            handle(try RoutineImporter.lines(from: url))
        } catch {
            parsed = nil
            show("No pude leer el archivo. Probá exportarlo de nuevo o pegá el texto. (\(error.localizedDescription))", error: true)
        }
    }

    private func handle(_ lines: [String]) {
        let r = RoutineImporter.parse(lines)
        guard !r.days.isEmpty else {
            parsed = nil
            show("No encontré ejercicios. Revisá que la planilla tenga las columnas Día, Ejercicio, Series y Reps.", error: true)
            return
        }
        parsed = r
        let n = r.days.reduce(0) { $0 + $1.exercises.count }
        var text = "Encontré \(r.days.count) días y \(n) ejercicios\(r.profe.isEmpty ? "" : " de \(r.profe)"). Podés corregir nombres de día y reps antes de usarla."
        if r.days.contains(where: { $0.exercises.contains(where: \.warn) }) {
            text += "\nAlgunas reps parecen fechas (Excel las convirtió). Revisá las marcadas."
        }
        show(text, error: false)
    }

    private func show(_ text: String, error: Bool) {
        message = text
        isError = error
    }

    private func apply() {
        guard let parsed else { return }
        store.applyImport(parsed)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
