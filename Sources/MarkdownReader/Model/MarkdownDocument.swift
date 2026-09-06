import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

struct MarkdownDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.markdown, .plainText, .text] }
    static var writableContentTypes: [UTType] { [.markdown, .plainText] }

    var text: String
    var encoding: String.Encoding = .utf8

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try self.init(data: data)
    }

    /// Decodifica el fichero: UTF-8 y, si no es válido, Latin-1 (que nunca
    /// falla) para poder al menos mostrar el contenido.
    init(data: Data) throws {
        if let decoded = String(data: data, encoding: .utf8) {
            text = decoded
            encoding = .utf8
        } else if let decoded = String(data: data, encoding: .isoLatin1) {
            text = decoded
            encoding = .isoLatin1
        } else {
            throw CocoaError(.fileReadUnknownStringEncoding)
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: encodedData())
    }

    /// Bytes que se escriben al guardar, respetando la codificación original.
    func encodedData() -> Data {
        text.data(using: encoding) ?? Data(text.utf8)
    }

    // MARK: - Estadísticas

    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var lineCount: Int {
        text.isEmpty ? 0 : text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }

    var readingMinutes: Int {
        max(1, Int((Double(wordCount) / 220.0).rounded(.up)))
    }

    /// Marca o desmarca la casilla de una lista de tareas en la línea indicada.
    mutating func setTask(line: Int, checked: Bool) {
        var lines = text.components(separatedBy: "\n")
        guard line >= 0, line < lines.count else { return }
        guard let range = lines[line].range(of: "\\[[ xX]\\]", options: .regularExpression) else { return }
        lines[line].replaceSubrange(range, with: checked ? "[x]" : "[ ]")
        text = lines.joined(separator: "\n")
    }
}
