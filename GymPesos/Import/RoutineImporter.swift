import Foundation
import PDFKit

struct ImportedExercise: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var series: Int
    var reps: String
    /// Las reps parecen una fecha (Excel convirtió "10-12" en "10-dic").
    var warn: Bool
}

struct ImportedDay: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var exercises: [ImportedExercise]
}

struct ImportedRoutine: Equatable {
    var profe: String
    var days: [ImportedDay]
}

enum ImportError: LocalizedError {
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let why): why
        }
    }
}

/// Lee la planilla "Armar rutina" del profe (PDF, Excel o CSV) y arma los días.
enum RoutineImporter {
    static func lines(from url: URL) throws -> [String] {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            guard let doc = PDFDocument(url: url) else { throw ImportError.unreadable("No pude abrir el PDF.") }
            // Cada PDF se arma distinto: se prueban varias formas de leerlo y se queda con la que
            // encuentra más ejercicios.
            let candidates = [pdfLinesBySelection(doc), pdfLines(doc), pdfPlainLines(doc)]
            return candidates.max { exerciseCount($0) < exerciseCount($1) } ?? []
        case "xlsx":
            let data = try Data(contentsOf: url)
            return try XLSXReader.rows(from: data).map(joinCells)
        case "csv", "txt":
            let data = try Data(contentsOf: url)
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            return csvLines(text)
        case "xls":
            throw ImportError.unreadable("El formato .xls viejo no se puede leer. Abrilo en Excel y guardalo como .xlsx o .csv, o exportalo a PDF.")
        default:
            throw ImportError.unreadable("Ese tipo de archivo no se puede leer. Usá PDF, Excel (.xlsx) o CSV.")
        }
    }

    private static func joinCells(_ cells: [String]) -> String {
        cells.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "  ")
    }

    // MARK: PDF

    private static func exerciseCount(_ lines: [String]) -> Int {
        parse(lines).days.reduce(0) { $0 + $1.exercises.count }
    }

    /// El texto del PDF tal cual lo da PDFKit.
    static func pdfPlainLines(_ doc: PDFDocument) -> [String] {
        (0..<doc.pageCount).flatMap { i in
            (doc.page(at: i)?.string ?? "").components(separatedBy: .newlines)
        }
    }

    /// Arma renglones con los pedazos de texto que PDFKit separa por línea (cada celda de la
    /// planilla), juntando los que están a la misma altura de izquierda a derecha.
    static func pdfLinesBySelection(_ doc: PDFDocument) -> [String] {
        struct Piece { let x: CGFloat; let y: CGFloat; let text: String }
        var out: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i),
                  let all = page.selection(for: page.bounds(for: .mediaBox)) else { continue }
            var pieces: [Piece] = []
            for sel in all.selectionsByLine() {
                let text = (sel.string ?? "").components(separatedBy: .newlines)
                    .joined(separator: " ").trimmingCharacters(in: .whitespaces)
                let b = sel.bounds(for: page)
                if text.isEmpty || b.isEmpty || b.height.isNaN { continue }
                pieces.append(Piece(x: b.minX, y: b.midY, text: text))
            }
            var rows: [(y: CGFloat, pieces: [Piece])] = []
            for p in pieces {
                if let k = rows.firstIndex(where: { abs($0.y - p.y) < 4 }) {
                    rows[k].pieces.append(p)
                } else {
                    rows.append((p.y, [p]))
                }
            }
            rows.sort { $0.y > $1.y }
            for row in rows {
                out.append(row.pieces.sorted { $0.x < $1.x }.map(\.text).joined(separator: "  "))
            }
        }
        return out
    }

    /// Arma renglones juntando las letras que están a la misma altura, de izquierda a derecha.
    static func pdfLines(_ doc: PDFDocument) -> [String] {
        struct Glyph { let ch: String; let x: CGFloat; let maxX: CGFloat; let y: CGFloat; let h: CGFloat }
        var out: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let raw = page.string else { continue }
            let text = raw as NSString
            var glyphs: [Glyph] = []
            for j in 0..<text.length {
                let ch = text.substring(with: NSRange(location: j, length: 1))
                if ch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                let b = page.characterBounds(at: j)
                if b.isEmpty || b.width.isNaN { continue }
                glyphs.append(Glyph(ch: ch, x: b.minX, maxX: b.maxX, y: b.midY, h: b.height))
            }
            var rows: [(y: CGFloat, glyphs: [Glyph])] = []
            for g in glyphs {
                if let k = rows.firstIndex(where: { abs($0.y - g.y) < 3 }) {
                    rows[k].glyphs.append(g)
                } else {
                    rows.append((g.y, [g]))
                }
            }
            rows.sort { $0.y > $1.y }
            for row in rows {
                let sorted = row.glyphs.sorted { $0.x < $1.x }
                var line = ""
                var lastMax: CGFloat?
                for g in sorted {
                    if let lastMax, g.x - lastMax > max(1, g.h * 0.15) { line += " " }
                    line += g.ch
                    lastMax = g.maxX
                }
                out.append(line)
            }
        }
        return out
    }

    // MARK: CSV

    static func csvLines(_ text: String) -> [String] {
        let rows = text.components(separatedBy: .newlines)
        let first = rows.first { !$0.isEmpty } ?? ""
        let sep: Character = first.filter { $0 == ";" }.count > first.filter { $0 == "," }.count ? ";" : ","
        return rows.map { row in
            joinCells(row.split(separator: sep, omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            })
        }
    }

    // MARK: Reconocer días y ejercicios

    private static let meses = [
        "ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8,
        "sep": 9, "set": 9, "oct": 10, "nov": 11, "dic": 12,
        "jan": 1, "apr": 4, "aug": 8, "dec": 12,
    ]

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static let profeRx = regex(#"Profesor[a]?\s*:\s*(.+)$"#)
    private static let dayRx = regex(#"^D[IÍ]A\s*(\d+)\s*(.*)$"#)
    private static let exRx = regex(#"^(\d{1,2})\s+(.+?)\s+(\d{1,2})\s+(\d\S*)(?:\s+.*)?$"#)
    private static let dateRx = regex(#"^(\d+)-([a-z]{3})\.?$"#)
    /// "10/10/2010": Excel convirtió las reps en fecha completa.
    private static let fullDateRx = regex(#"^\d{1,2}/\d{1,2}/\d{2,4}$"#)

    private static func groups(_ rx: NSRegularExpression, _ s: String) -> [String]? {
        let ns = s as NSString
        guard let m = rx.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }

    static func parse(_ lines: [String]) -> ImportedRoutine {
        var days: [ImportedDay] = []
        var profe = ""
        for raw in lines {
            // Letras con tilde separadas (I + ´) se vuelven a juntar.
            let line = raw.precomposedStringWithCanonicalMapping.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            if line.isEmpty { continue }
            if let g = groups(profeRx, line) { profe = g[1].trimmingCharacters(in: .whitespaces) }
            if let g = groups(dayRx, line) {
                // "DÍA 1: Pecho y Bíceps" → "Pecho y Bíceps".
                var name = g[2].trimmingCharacters(in: CharacterSet(charactersIn: " :-–—.\t"))
                // A veces el PDF repite el nombre: "Pecho y Bíceps Pecho y Bíceps".
                let words = name.split(separator: " ")
                if words.count % 2 == 0, !words.isEmpty {
                    let half = words.count / 2
                    let a = words[..<half].joined(separator: " "), b = words[half...].joined(separator: " ")
                    if a.lowercased() == b.lowercased() { name = a }
                }
                days.append(ImportedDay(name: name.isEmpty ? "Día \(g[1])" : name, exercises: []))
                continue
            }
            if let g = groups(exRx, line), !days.isEmpty {
                var reps = g[4]
                var warn = false
                if let d = groups(dateRx, reps), let m = meses[d[2].lowercased()] {
                    reps = "\(d[1])-\(m)"
                    warn = true
                } else if groups(fullDateRx, reps) != nil {
                    warn = true
                } else if let serial = Int(reps), (20000...80000).contains(serial) {
                    // Excel guardó las reps como fecha (número de serie).
                    let base = DateComponents(calendar: Calendar(identifier: .gregorian), year: 1899, month: 12, day: 30).date!
                    if let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: serial, to: base) {
                        let c = Calendar(identifier: .gregorian).dateComponents([.day, .month], from: date)
                        reps = "\(c.day ?? 0)-\(c.month ?? 0)"
                        warn = true
                    }
                }
                days[days.count - 1].exercises.append(ImportedExercise(
                    name: g[2].trimmingCharacters(in: .whitespaces),
                    series: Int(g[3]) ?? 3,
                    reps: reps,
                    warn: warn
                ))
            }
        }
        return ImportedRoutine(profe: profe, days: days.filter { !$0.exercises.isEmpty })
    }
}
