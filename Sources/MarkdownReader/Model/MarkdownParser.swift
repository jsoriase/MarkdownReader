import Foundation

/// Parser de bloques Markdown (CommonMark + extensiones GFM más habituales).
///
/// El parseo *inline* (negritas, enlaces, código…) se delega en el parser de
/// Foundation dentro de `InlineRenderer`; aquí sólo se resuelve la estructura
/// de bloques, que es lo que Foundation no expone de forma cómoda.
final class MarkdownParser {

    private var counter = 0
    private var slugCounts: [String: Int] = [:]
    private var headings: [MDHeading] = []
    private var linkDefs: [String: String] = [:]

    // MARK: - API

    static func parse(_ text: String) -> MDDocument {
        MarkdownParser().run(text)
    }

    private func run(_ text: String) -> MDDocument {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines: [SrcLine] = []
        for (idx, raw) in normalized.components(separatedBy: "\n").enumerated() {
            lines.append(SrcLine(number: idx, text: raw))
        }

        var blocks: [MDBlock] = []
        var start = 0
        if let (pairs, end) = frontMatter(lines) {
            blocks.append(.frontMatter(id: nextID("fm"), pairs: pairs))
            start = end
        }
        blocks.append(contentsOf: parseBlocks(Array(lines[start...])))

        var doc = MDDocument()
        doc.blocks = blocks
        doc.headings = headings
        doc.linkDefinitions = linkDefs
        return doc
    }

    // MARK: - Front matter (YAML sencillo)

    private func frontMatter(_ lines: [SrcLine]) -> ([MDPair], Int)? {
        guard let first = lines.first, first.text.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        var idx = 1
        while idx < lines.count {
            let t = lines[idx].text.trimmingCharacters(in: .whitespaces)
            if t == "---" || t == "..." {
                var pairs: [MDPair] = []
                for l in lines[1..<idx] {
                    let line = l.text
                    guard let colon = line.firstIndex(of: ":") else { continue }
                    let key = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                    var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if key.isEmpty || key.hasPrefix("#") { continue }
                    pairs.append(MDPair(key: key, value: value))
                }
                return (pairs, idx + 1)
            }
            idx += 1
        }
        return nil
    }

    // MARK: - Bloques

    private func parseBlocks(_ lines: [SrcLine]) -> [MDBlock] {
        var blocks: [MDBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            if Self.isBlank(line.text) { i += 1; continue }

            // Definición de enlace por referencia
            if let def = Self.linkDefinition(line.text) {
                linkDefs[def.0] = def.1
                i += 1
                continue
            }

            if let f = Self.fence(line.text) {
                i += 1
                var body: [String] = []
                while i < lines.count {
                    if let closing = Self.fence(lines[i].text),
                       closing.char == f.char, closing.length >= f.length, closing.info.isEmpty {
                        i += 1
                        break
                    }
                    body.append(Self.dedent(lines[i].text, by: f.indent))
                    i += 1
                }
                let lang = f.info.split(separator: " ").first.map(String.init)
                blocks.append(.code(MDCode(id: nextID("code"),
                                           language: lang?.isEmpty == false ? lang : nil,
                                           code: body.joined(separator: "\n"),
                                           line: line.number)))
                continue
            }

            if let (level, content) = Self.atx(line.text) {
                blocks.append(.heading(makeHeading(level: level, markdown: content, line: line.number)))
                i += 1
                continue
            }

            if Self.isThematicBreak(line.text) {
                blocks.append(.rule(id: nextID("hr")))
                i += 1
                continue
            }

            if Self.quoteStrip(line.text) != nil {
                var inner: [SrcLine] = []
                while i < lines.count {
                    let l = lines[i]
                    if let stripped = Self.quoteStrip(l.text) {
                        inner.append(SrcLine(number: l.number, text: stripped))
                        i += 1
                    } else if !Self.isBlank(l.text), !Self.startsBlock(l.text), Self.marker(l.text) == nil {
                        // continuación perezosa
                        inner.append(SrcLine(number: l.number, text: l.text))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.quote(id: nextID("quote"), blocks: parseBlocks(inner)))
                continue
            }

            if Self.marker(line.text) != nil {
                blocks.append(.list(parseList(lines, &i)))
                continue
            }

            if Self.indent(line.text) >= 4 {
                var body: [String] = []
                while i < lines.count {
                    let l = lines[i]
                    if Self.isBlank(l.text) {
                        // sólo continúa si después sigue habiendo código indentado
                        var j = i
                        while j < lines.count, Self.isBlank(lines[j].text) { j += 1 }
                        if j < lines.count, Self.indent(lines[j].text) >= 4 {
                            body.append(contentsOf: Array(repeating: "", count: j - i))
                            i = j
                            continue
                        }
                        break
                    }
                    guard Self.indent(l.text) >= 4 else { break }
                    body.append(Self.dedent(l.text, by: 4))
                    i += 1
                }
                blocks.append(.code(MDCode(id: nextID("code"), language: nil,
                                           code: body.joined(separator: "\n"), line: line.number)))
                continue
            }

            if line.text.contains("|"), i + 1 < lines.count, Self.isDelimiterRow(lines[i + 1].text) {
                blocks.append(.table(parseTable(lines, &i)))
                continue
            }

            if Self.isHTMLBlockStart(line.text) {
                var body: [String] = []
                while i < lines.count, !Self.isBlank(lines[i].text) {
                    body.append(lines[i].text)
                    i += 1
                }
                let raw = body.joined(separator: "\n")
                if let img = Self.standaloneImageTag(raw) {
                    blocks.append(.image(MDImageBlock(id: nextID("img"), source: img.0, alt: img.1, title: nil)))
                } else {
                    let text = Self.stripTags(raw)
                    blocks.append(.html(id: nextID("html"), raw: raw, text: text))
                }
                continue
            }

            // Párrafo (o título setext)
            var buf: [SrcLine] = []
            var madeHeading = false
            while i < lines.count {
                let l = lines[i]
                if Self.isBlank(l.text) { break }
                if !buf.isEmpty, let level = Self.setext(l.text) {
                    let markdown = buf.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                    blocks.append(.heading(makeHeading(level: level, markdown: markdown, line: buf[0].number)))
                    i += 1
                    madeHeading = true
                    break
                }
                if !buf.isEmpty, Self.startsBlock(l.text) || Self.marker(l.text) != nil { break }
                buf.append(l)
                i += 1
            }
            if madeHeading || buf.isEmpty { continue }

            if buf.count == 1, let img = Self.standaloneImage(buf[0].text) {
                blocks.append(.image(MDImageBlock(id: nextID("img"), source: img.source, alt: img.alt, title: img.title)))
                continue
            }

            var pieces: [String] = []
            for (idx, l) in buf.enumerated() {
                var t = l.text
                let hardBreak = t.hasSuffix("  ") || t.hasSuffix("\\")
                if t.hasSuffix("\\") { t.removeLast() }
                t = t.trimmingCharacters(in: .whitespaces)
                pieces.append(t)
                if idx < buf.count - 1 { pieces.append(hardBreak ? "\n" : " ") }
            }
            blocks.append(.paragraph(id: nextID("p"), markdown: pieces.joined(), line: buf[0].number))
        }

        return blocks
    }

    // MARK: - Listas

    private func parseList(_ lines: [SrcLine], _ i: inout Int) -> MDList {
        let first = Self.marker(lines[i].text)!
        let ordered = first.ordered
        let listIndent = first.indent
        var items: [MDListItem] = []
        var loose = false

        while i < lines.count {
            let line = lines[i]

            if Self.isBlank(line.text) {
                var j = i
                while j < lines.count, Self.isBlank(lines[j].text) { j += 1 }
                guard j < lines.count, let m = Self.marker(lines[j].text),
                      m.ordered == ordered, m.indent >= listIndent, m.indent <= listIndent + 3 else { break }
                loose = true
                i = j
                continue
            }

            guard let m = Self.marker(line.text), m.ordered == ordered,
                  m.indent >= listIndent, m.indent <= listIndent + 3 else { break }

            var itemLines: [SrcLine] = [SrcLine(number: line.number, text: m.rest)]
            i += 1
            var pendingBlanks: [SrcLine] = []

            while i < lines.count {
                let l = lines[i]
                if Self.isBlank(l.text) {
                    pendingBlanks.append(SrcLine(number: l.number, text: ""))
                    i += 1
                    continue
                }
                if Self.indent(l.text) >= m.contentIndent {
                    if !pendingBlanks.isEmpty {
                        itemLines.append(contentsOf: pendingBlanks)
                        pendingBlanks.removeAll()
                        loose = true
                    }
                    itemLines.append(SrcLine(number: l.number, text: Self.dedent(l.text, by: m.contentIndent)))
                    i += 1
                    continue
                }
                if pendingBlanks.isEmpty, Self.marker(l.text) == nil, !Self.startsBlock(l.text) {
                    itemLines.append(SrcLine(number: l.number, text: l.text.trimmingCharacters(in: .whitespaces)))
                    i += 1
                    continue
                }
                break
            }
            i -= pendingBlanks.count

            var checked: Bool? = nil
            var checkboxLine: Int? = nil
            if let head = itemLines.first {
                let t = head.text
                if let r = t.range(of: "^\\[([ xX])\\](\\s+|$)", options: .regularExpression) {
                    let mark = t[t.index(t.startIndex, offsetBy: 1)]
                    checked = (mark == "x" || mark == "X")
                    checkboxLine = head.number
                    itemLines[0] = SrcLine(number: head.number, text: String(t[r.upperBound...]))
                }
            }

            items.append(MDListItem(id: nextID("li"),
                                    checked: checked,
                                    checkboxLine: checkboxLine,
                                    blocks: parseBlocks(itemLines)))
        }

        return MDList(id: nextID("list"), ordered: ordered, start: first.number,
                      tight: !loose, items: items)
    }

    // MARK: - Tablas

    private func parseTable(_ lines: [SrcLine], _ i: inout Int) -> MDTable {
        let header = Self.splitRow(lines[i].text)
        let alignments = Self.splitRow(lines[i + 1].text).map { cell -> MDAlignment in
            let t = cell.trimmingCharacters(in: .whitespaces)
            let left = t.hasPrefix(":")
            let right = t.hasSuffix(":")
            switch (left, right) {
            case (true, true): return .center
            case (true, false): return .left
            case (false, true): return .right
            default: return .none
            }
        }
        i += 2
        var rows: [[String]] = []
        while i < lines.count, !Self.isBlank(lines[i].text), lines[i].text.contains("|") {
            var cells = Self.splitRow(lines[i].text)
            while cells.count < header.count { cells.append("") }
            if cells.count > header.count { cells = Array(cells[0..<header.count]) }
            rows.append(cells)
            i += 1
        }
        var aligns = alignments
        while aligns.count < header.count { aligns.append(.none) }
        return MDTable(id: nextID("table"), header: header, alignments: aligns, rows: rows)
    }

    // MARK: - Utilidades

    private func nextID(_ prefix: String) -> String {
        counter += 1
        return "\(prefix)-\(counter)"
    }

    private func makeHeading(level: Int, markdown: String, line: Int) -> MDHeading {
        let plain = Self.plainText(markdown)
        let heading = MDHeading(id: slug(for: plain), level: level, markdown: markdown, plain: plain, line: line)
        headings.append(heading)
        return heading
    }

    private func slug(for text: String) -> String {
        var base = ""
        for ch in text.lowercased() {
            if ch.isLetter || ch.isNumber { base.append(ch) }
            else if ch == " " || ch == "-" || ch == "_" { base.append("-") }
        }
        while base.contains("--") { base = base.replacingOccurrences(of: "--", with: "-") }
        base = base.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if base.isEmpty { base = "seccion" }
        let n = slugCounts[base, default: 0]
        slugCounts[base] = n + 1
        return n == 0 ? base : "\(base)-\(n)"
    }

    static func plainText(_ markdown: String) -> String {
        var s = markdown
        s = s.replacingOccurrences(of: "!?\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "!?\\[([^\\]]*)\\]\\[[^\\]]*\\]", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "`([^`]*)`", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "[*_~]", with: "", options: .regularExpression)
        s = stripTags(s)
        return s.trimmingCharacters(in: .whitespaces)
    }

    static func isBlank(_ s: String) -> Bool {
        s.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func indent(_ s: String) -> Int {
        var n = 0
        for ch in s {
            if ch == " " { n += 1 }
            else if ch == "\t" { n += 4 - (n % 4) }
            else { break }
        }
        return n
    }

    static func dedent(_ s: String, by amount: Int) -> String {
        guard amount > 0 else { return s }
        var removed = 0
        var idx = s.startIndex
        while idx < s.endIndex, removed < amount {
            let ch = s[idx]
            if ch == " " { removed += 1 }
            else if ch == "\t" { removed += 4 - (removed % 4) }
            else { break }
            idx = s.index(after: idx)
        }
        return String(s[idx...])
    }

    struct Fence {
        let char: Character
        let length: Int
        let info: String
        let indent: Int
    }

    static func fence(_ s: String) -> Fence? {
        let ind = indent(s)
        guard ind < 4 else { return nil }
        let body = Substring(s).drop { $0 == " " || $0 == "\t" }
        guard let first = body.first, first == "`" || first == "~" else { return nil }
        let run = body.prefix { $0 == first }.count
        guard run >= 3 else { return nil }
        let info = String(body.dropFirst(run)).trimmingCharacters(in: .whitespaces)
        if first == "`", info.contains("`") { return nil }
        return Fence(char: first, length: run, info: info, indent: ind)
    }

    static func atx(_ s: String) -> (Int, String)? {
        guard indent(s) < 4 else { return nil }
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("#") else { return nil }
        let hashes = t.prefix { $0 == "#" }.count
        guard hashes <= 6 else { return nil }
        let rest = String(t.dropFirst(hashes))
        guard rest.isEmpty || rest.hasPrefix(" ") || rest.hasPrefix("\t") else { return nil }
        var content = rest.trimmingCharacters(in: .whitespaces)
        if content.hasSuffix("#") {
            let trimmed = String(String(content.reversed()).drop { $0 == "#" }.reversed())
            if trimmed.isEmpty || trimmed.hasSuffix(" ") {
                content = trimmed.trimmingCharacters(in: .whitespaces)
            }
        }
        return (hashes, content)
    }

    static func isThematicBreak(_ s: String) -> Bool {
        guard indent(s) < 4 else { return false }
        let t = s.filter { $0 != " " && $0 != "\t" }
        guard t.count >= 3 else { return false }
        return t.allSatisfy { $0 == "-" } || t.allSatisfy { $0 == "*" } || t.allSatisfy { $0 == "_" }
    }

    static func setext(_ s: String) -> Int? {
        guard indent(s) < 4 else { return nil }
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if t.allSatisfy({ $0 == "=" }) { return 1 }
        if t.count >= 2, t.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }

    static func quoteStrip(_ s: String) -> String? {
        guard indent(s) < 4 else { return nil }
        var t = Substring(s).drop { $0 == " " || $0 == "\t" }
        guard t.first == ">" else { return nil }
        t = t.dropFirst()
        if t.first == " " { t = t.dropFirst() }
        return String(t)
    }

    struct Marker {
        let ordered: Bool
        let number: Int
        let indent: Int
        let contentIndent: Int
        let rest: String
    }

    static func marker(_ s: String) -> Marker? {
        let ind = indent(s)
        guard ind <= 3 else { return nil }
        let body = Substring(s).drop { $0 == " " || $0 == "\t" }
        guard let first = body.first else { return nil }

        func make(width: Int, after: Substring, ordered: Bool, number: Int) -> Marker {
            let spaces = after.prefix { $0 == " " || $0 == "\t" }.count
            let rest = String(after.drop { $0 == " " || $0 == "\t" })
            let padding = rest.isEmpty ? 1 : min(max(spaces, 1), 4)
            return Marker(ordered: ordered, number: number, indent: ind,
                          contentIndent: ind + width + padding, rest: rest)
        }

        if first == "-" || first == "*" || first == "+" {
            if isThematicBreak(s) { return nil }
            let after = body.dropFirst()
            guard after.isEmpty || after.hasPrefix(" ") || after.hasPrefix("\t") else { return nil }
            return make(width: 1, after: after, ordered: false, number: 1)
        }

        let digits = body.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 9 else { return nil }
        let afterDigits = body.dropFirst(digits.count)
        guard let delim = afterDigits.first, delim == "." || delim == ")" else { return nil }
        let after = afterDigits.dropFirst()
        guard after.isEmpty || after.hasPrefix(" ") || after.hasPrefix("\t") else { return nil }
        return make(width: digits.count + 1, after: after, ordered: true, number: Int(digits) ?? 1)
    }

    /// ¿La línea abre un bloque distinto a un párrafo?
    static func startsBlock(_ s: String) -> Bool {
        if fence(s) != nil { return true }
        if atx(s) != nil { return true }
        if isThematicBreak(s) { return true }
        if quoteStrip(s) != nil { return true }
        if isHTMLBlockStart(s) { return true }
        return false
    }

    static func linkDefinition(_ s: String) -> (String, String)? {
        guard indent(s) < 4 else { return nil }
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("["), let close = t.range(of: "]:") else { return nil }
        let label = String(t[t.index(after: t.startIndex)..<close.lowerBound])
        guard !label.isEmpty, !label.contains("[") else { return nil }
        var dest = String(t[close.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !dest.isEmpty else { return nil }
        if let space = dest.firstIndex(of: " ") { dest = String(dest[dest.startIndex..<space]) }
        dest = dest.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        return (label.lowercased(), dest)
    }

    static func isDelimiterRow(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.contains("-"), t.contains("|") || t.hasPrefix(":") || t.hasPrefix("-") else { return false }
        guard t.allSatisfy({ "-:| \t".contains($0) }) else { return false }
        let cells = splitRow(t)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            var y = Substring(cell.trimmingCharacters(in: .whitespaces))
            if y.first == ":" { y = y.dropFirst() }
            if y.last == ":" { y = y.dropLast() }
            return !y.isEmpty && y.allSatisfy { $0 == "-" }
        }
    }

    static func splitRow(_ s: String) -> [String] {
        var t = Substring(s.trimmingCharacters(in: .whitespaces))
        if t.hasPrefix("|") { t = t.dropFirst() }
        if t.hasSuffix("|"), !t.hasSuffix("\\|") { t = t.dropLast() }
        var cells: [String] = []
        var current = ""
        var escaped = false
        for ch in t {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" {
                escaped = true
                current.append(ch)
                continue
            }
            if ch == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                continue
            }
            current.append(ch)
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    static func isHTMLBlockStart(_ s: String) -> Bool {
        guard indent(s) < 4 else { return false }
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("<"), t.count > 1 else { return false }
        let second = t[t.index(after: t.startIndex)]
        return second.isLetter || second == "/" || second == "!"
    }

    static func stripTags(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        out = out.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: "&nbsp;", with: " ")
        out = out.replacingOccurrences(of: "&amp;", with: "&")
        out = out.replacingOccurrences(of: "&lt;", with: "<")
        out = out.replacingOccurrences(of: "&gt;", with: ">")
        out = out.replacingOccurrences(of: "&quot;", with: "\"")
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func standaloneImage(_ s: String) -> (source: String, alt: String, title: String?)? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("!["), t.hasSuffix(")") else { return nil }
        guard let close = t.range(of: "](") else { return nil }
        let alt = String(t[t.index(t.startIndex, offsetBy: 2)..<close.lowerBound])
        guard !alt.contains("![") else { return nil }
        var dest = String(t[close.upperBound..<t.index(before: t.endIndex)]).trimmingCharacters(in: .whitespaces)
        guard !dest.contains("!["), !dest.contains("](") else { return nil }
        var title: String? = nil
        if let quote = dest.range(of: " \"") {
            title = String(dest[quote.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            dest = String(dest[dest.startIndex..<quote.lowerBound])
        }
        dest = dest.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
        guard !dest.isEmpty else { return nil }
        return (dest, alt, title)
    }

    static func standaloneImageTag(_ s: String) -> (String, String)? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.lowercased().hasPrefix("<img"), !t.dropFirst(4).contains("<") else { return nil }
        func attr(_ name: String) -> String? {
            let pattern = "\(name)\\s*=\\s*[\"']([^\"']*)[\"']"
            guard let r = t.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
            let piece = String(t[r])
            guard let q = piece.range(of: "[\"']", options: .regularExpression) else { return nil }
            return String(piece[q.upperBound..<piece.index(before: piece.endIndex)])
        }
        guard let src = attr("src") else { return nil }
        return (src, attr("alt") ?? "")
    }
}
