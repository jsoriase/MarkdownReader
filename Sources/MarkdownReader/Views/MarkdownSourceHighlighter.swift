import AppKit

/// Markdown highlighting for the source view.
enum MarkdownSourceHighlighter {

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern)
    }

    private static let heading = regex("^\\s{0,3}#{1,6}\\s.*$")
    private static let quote = regex("^\\s{0,3}>.*$")
    private static let listMarker = regex("^\\s*([-*+]|\\d{1,9}[.)])\\s")
    private static let rule = regex("^\\s{0,3}([-*_])(\\s*\\1){2,}\\s*$")
    private static let inlineCode = regex("`[^`\\n]+`")
    private static let strong = regex("(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1")
    private static let emphasis = regex("(?<![*_\\w])([*_])(?=\\S)([^*_\\n]+?)(?<=\\S)\\1(?![*_\\w])")
    private static let strike = regex("~~(?=\\S)(.+?)(?<=\\S)~~")
    private static let link = regex("(!?)\\[([^\\]\\n]*)\\]\\(([^)\\n]*)\\)")
    private static let htmlTag = regex("</?[A-Za-z][^>\\n]*>")
    private static let taskBox = regex("^\\s*[-*+]\\s\\[[ xX]\\]")

    static func apply(to storage: NSTextStorage, font: NSFont, enabled: Bool) {
        let ns = storage.string as NSString
        let full = NSRange(location: 0, length: ns.length)

        storage.beginEditing()
        defer { storage.endEditing() }

        storage.setAttributes([.font: font, .foregroundColor: NSColor.textColor], range: full)
        guard enabled, ns.length < 400_000 else { return }

        let accent = NSColor.controlAccentColor
        let codeColor = NSColor.systemTeal
        let inlineCodeColor = NSColor.systemPink
        let dim = NSColor.tertiaryLabelColor
        let secondary = NSColor.secondaryLabelColor
        let marker = NSColor.systemOrange

        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)

        var inFence = false
        var location = 0

        while location < ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
            let line = ns.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            location = NSMaxRange(lineRange)
            if lineRange.length == 0 { break }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                storage.addAttribute(.foregroundColor, value: dim, range: lineRange)
                continue
            }
            if inFence {
                storage.addAttribute(.foregroundColor, value: codeColor, range: lineRange)
                continue
            }
            if line.hasPrefix("    ") || line.hasPrefix("\t") {
                storage.addAttribute(.foregroundColor, value: codeColor, range: lineRange)
                continue
            }

            if heading?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
                storage.addAttributes([.foregroundColor: accent, .font: boldFont], range: lineRange)
                highlightInline(storage, line: line, lineRange: lineRange,
                                inlineCodeColor: inlineCodeColor, secondary: secondary,
                                accent: accent, font: font, boldFont: boldFont, italicFont: italicFont)
                continue
            }

            if rule?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
                storage.addAttribute(.foregroundColor, value: dim, range: lineRange)
                continue
            }

            if quote?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
                storage.addAttributes([.foregroundColor: secondary, .font: italicFont], range: lineRange)
            }

            let lineLength = line.utf16.count
            if let match = listMarker?.firstMatch(in: line, range: NSRange(location: 0, length: lineLength)) {
                storage.addAttribute(.foregroundColor, value: marker,
                                     range: shift(match.range, by: lineRange.location, limit: ns.length))
            }
            if let match = taskBox?.firstMatch(in: line, range: NSRange(location: 0, length: lineLength)) {
                storage.addAttributes([.foregroundColor: accent, .font: boldFont],
                                      range: shift(match.range, by: lineRange.location, limit: ns.length))
            }

            highlightInline(storage, line: line, lineRange: lineRange,
                            inlineCodeColor: inlineCodeColor, secondary: secondary,
                            accent: accent, font: font, boldFont: boldFont, italicFont: italicFont)
        }
    }

    private static func highlightInline(_ storage: NSTextStorage,
                                        line: String,
                                        lineRange: NSRange,
                                        inlineCodeColor: NSColor,
                                        secondary: NSColor,
                                        accent: NSColor,
                                        font: NSFont,
                                        boldFont: NSFont,
                                        italicFont: NSFont) {
        let length = line.utf16.count
        let whole = NSRange(location: 0, length: length)
        let limit = storage.length

        strong?.enumerateMatches(in: line, range: whole) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.font, value: boldFont, range: shift(match.range, by: lineRange.location, limit: limit))
        }
        emphasis?.enumerateMatches(in: line, range: whole) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.font, value: italicFont, range: shift(match.range, by: lineRange.location, limit: limit))
        }
        strike?.enumerateMatches(in: line, range: whole) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue,
                                 range: shift(match.range, by: lineRange.location, limit: limit))
        }
        link?.enumerateMatches(in: line, range: whole) { match, _, _ in
            guard let match, match.numberOfRanges >= 4 else { return }
            storage.addAttribute(.foregroundColor, value: accent,
                                 range: shift(match.range(at: 2), by: lineRange.location, limit: limit))
            storage.addAttribute(.foregroundColor, value: secondary,
                                 range: shift(match.range(at: 3), by: lineRange.location, limit: limit))
        }
        htmlTag?.enumerateMatches(in: line, range: whole) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.foregroundColor, value: secondary,
                                 range: shift(match.range, by: lineRange.location, limit: limit))
        }
        inlineCode?.enumerateMatches(in: line, range: whole) { match, _, _ in
            guard let match else { return }
            let range = shift(match.range, by: lineRange.location, limit: limit)
            storage.addAttributes([.foregroundColor: inlineCodeColor, .font: font], range: range)
        }
    }

    private static func shift(_ range: NSRange, by offset: Int, limit: Int) -> NSRange {
        guard range.location != NSNotFound else { return NSRange(location: 0, length: 0) }
        let location = min(range.location + offset, limit)
        let length = min(range.length, max(0, limit - location))
        return NSRange(location: location, length: length)
    }
}
