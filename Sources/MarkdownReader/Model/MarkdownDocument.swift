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

    /// Decodes the file: UTF-8 first and, when that fails, Latin-1 (which
    /// never fails) so the content can at least be shown.
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

    /// The bytes written on save, preserving the file's original encoding.
    func encodedData() -> Data {
        text.data(using: encoding) ?? Data(text.utf8)
    }

    // MARK: - Statistics

    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var lineCount: Int {
        text.isEmpty ? 0 : text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }

    var readingMinutes: Int {
        max(1, Int((Double(wordCount) / 220.0).rounded(.up)))
    }

    /// Ticks or unticks the task list checkbox on the given line.
    mutating func setTask(line: Int, checked: Bool) {
        var lines = text.components(separatedBy: "\n")
        guard line >= 0, line < lines.count else { return }
        guard let range = lines[line].range(of: "\\[[ xX]\\]", options: .regularExpression) else { return }
        lines[line].replaceSubrange(range, with: checked ? "[x]" : "[ ]")
        text = lines.joined(separator: "\n")
    }
}
