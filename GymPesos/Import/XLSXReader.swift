import Compression
import Foundation

/// Lector mínimo de Excel (.xlsx): abre el zip y lee la primera hoja como filas de texto.
enum XLSXReader {
    static func rows(from data: Data) throws -> [[String]] {
        let zip = try Zip(data)
        let shared = try zip.file("xl/sharedStrings.xml").map(SharedStringsParser.parse) ?? []
        let sheetPath = firstSheetPath(zip) ?? "xl/worksheets/sheet1.xml"
        guard let sheet = try zip.file(sheetPath) ?? zip.file("xl/worksheets/sheet1.xml") else {
            throw ImportError.unreadable("El Excel no tiene hojas.")
        }
        return SheetParser.parse(sheet, shared: shared)
    }

    /// Ruta de la primera hoja según workbook.xml y sus relaciones.
    private static func firstSheetPath(_ zip: Zip) -> String? {
        guard let wb = try? zip.file("xl/workbook.xml"),
              let rels = try? zip.file("xl/_rels/workbook.xml.rels") else { return nil }
        let wbText = String(decoding: wb, as: UTF8.self)
        let relText = String(decoding: rels, as: UTF8.self)
        guard let sheetTag = firstMatch(#"<sheet\b[^>]*>"#, in: wbText),
              let rid = firstMatch(#"r:id="([^"]+)""#, in: sheetTag, group: 1) else { return nil }
        let relPattern = #"<Relationship\b[^>]*Id=""# + NSRegularExpression.escapedPattern(for: rid) + #""[^>]*>"#
        guard let relTag = firstMatch(relPattern, in: relText),
              let target = firstMatch(#"Target="([^"]+)""#, in: relTag, group: 1) else { return nil }
        if target.hasPrefix("/") { return String(target.dropFirst()) }
        return "xl/" + target
    }

    private static func firstMatch(_ pattern: String, in text: String, group: Int = 0) -> String? {
        guard let rx = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = rx.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.range(at: group).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: group))
    }
}

// MARK: - Zip

private struct Zip {
    private let bytes: [UInt8]
    private var entries: [String: (method: Int, compSize: Int, size: Int, offset: Int)] = [:]

    init(_ data: Data) throws {
        bytes = [UInt8](data)
        guard bytes.count > 22 else { throw ImportError.unreadable("El archivo está vacío o dañado.") }
        // Fin del directorio central: se busca desde el final.
        var eocd = -1
        var i = bytes.count - 22
        let lowest = max(0, bytes.count - 22 - 65535)
        while i >= lowest {
            if u32(i) == 0x0605_4b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ImportError.unreadable("No parece un Excel (.xlsx) válido.") }
        let count = u16(eocd + 10)
        var p = u32(eocd + 16)
        for _ in 0..<count {
            guard p + 46 <= bytes.count, u32(p) == 0x0201_4b50 else { break }
            let method = u16(p + 10)
            let compSize = u32(p + 20)
            let size = u32(p + 24)
            let nameLen = u16(p + 28), extraLen = u16(p + 30), commentLen = u16(p + 32)
            let offset = u32(p + 42)
            let nameEnd = min(bytes.count, p + 46 + nameLen)
            let name = String(decoding: bytes[(p + 46)..<nameEnd], as: UTF8.self)
            entries[name] = (method, compSize, size, offset)
            p += 46 + nameLen + extraLen + commentLen
        }
    }

    private func u16(_ i: Int) -> Int { Int(bytes[i]) | Int(bytes[i + 1]) << 8 }
    private func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }

    func file(_ name: String) throws -> Data? {
        guard let e = entries[name] else { return nil }
        guard e.offset + 30 <= bytes.count, u32(e.offset) == 0x0403_4b50 else {
            throw ImportError.unreadable("El Excel está dañado.")
        }
        let start = e.offset + 30 + u16(e.offset + 26) + u16(e.offset + 28)
        guard start + e.compSize <= bytes.count else { throw ImportError.unreadable("El Excel está dañado.") }
        let src = Array(bytes[start..<(start + e.compSize)])
        switch e.method {
        case 0:
            return Data(src)
        case 8:
            if e.size == 0 { return Data() }
            var dst = [UInt8](repeating: 0, count: e.size)
            let written = src.withUnsafeBufferPointer { s in
                dst.withUnsafeMutableBufferPointer { d in
                    compression_decode_buffer(d.baseAddress!, e.size, s.baseAddress!, src.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard written > 0 else { throw ImportError.unreadable("No pude descomprimir el Excel.") }
            return Data(dst.prefix(written))
        default:
            throw ImportError.unreadable("El Excel usa una compresión que no conozco.")
        }
    }
}

// MARK: - XML

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var current = ""
    private var inSI = false
    private var inT = false

    static func parse(_ data: Data) -> [String] {
        let handler = SharedStringsParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return handler.strings
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        if name == "si" { inSI = true; current = "" }
        if name == "t" { inT = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inSI && inT { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "t" { inT = false }
        if name == "si" { inSI = false; strings.append(current) }
    }
}

private final class SheetParser: NSObject, XMLParserDelegate {
    private let shared: [String]
    private var rows: [[String]] = []
    private var row: [Int: String] = [:]
    private var cellType = ""
    private var cellCol = 0
    private var value = ""
    private var capturing = false

    init(shared: [String]) { self.shared = shared }

    static func parse(_ data: Data, shared: [String]) -> [[String]] {
        let handler = SheetParser(shared: shared)
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return handler.rows
    }

    /// "C12" → 2 (columna empezando en 0).
    private static func column(_ ref: String) -> Int {
        var n = 0
        for ch in ref.uppercased() {
            guard let a = ch.asciiValue, a >= 65, a <= 90 else { break }
            n = n * 26 + Int(a - 64)
        }
        return max(0, n - 1)
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        switch name {
        case "row":
            row = [:]
        case "c":
            cellType = attributes["t"] ?? ""
            cellCol = attributes["r"].map(SheetParser.column) ?? (row.keys.max().map { $0 + 1 } ?? 0)
            value = ""
        case "v", "t":
            capturing = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { value += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "v", "t":
            capturing = false
        case "c":
            var text = value
            if cellType == "s", let i = Int(value), shared.indices.contains(i) { text = shared[i] }
            if cellType.isEmpty || cellType == "n", let d = Double(value), d == d.rounded(), abs(d) < 1e9 {
                text = String(Int(d))
            }
            row[cellCol] = text
        case "row":
            let last = row.keys.max() ?? -1
            rows.append(last < 0 ? [] : (0...last).map { row[$0] ?? "" })
        default:
            break
        }
    }
}
